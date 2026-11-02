import 'dart:convert';

import '../../constants/ai_constants.dart';
import '../../interfaces/ai_action_handler.dart';
import '../../models/ai_configuration.dart';
import '../../models/chat_message.dart';
import '../../models/function_call_response.dart';
import '../shared/ai_provider_client.dart';
import '../../interfaces/ai_service.dart';
import '../../helpers/json_schema_function_definition_mapper.dart';
import '../../helpers/prepare_chat_messages.dart';
import '../../failures/ai_provider_failure.dart';

import 'package:dio/dio.dart';

/// Talks to the OpenAI Responses API and runs its function-call loop.
class OpenAIService implements AIService {
  OpenAIService({
    required String apiKey,
    required this.modelName,
    required this.configuration,
    required this.actionHandler,
    AIProviderClient? client,
  }) : _client =
           client ??
           AIProviderClient(
             baseUrl: 'https://api.openai.com/v1/',
             headers: {'Authorization': 'Bearer $apiKey'},
           );

  static const _functionMapper = JsonSchemaFunctionDefinitionMapper();

  final AIProviderClient _client;

  @override
  final String modelName;

  @override
  final AIConfiguration configuration;

  @override
  final AiActionHandler actionHandler;

  @override
  Future<String> send(List<ChatMessage> messages, {String? additionalContext}) async {
    final requestMessages = prepareChatMessages(
      messages,
      contextSources: configuration.contextSources,
      additionalContext: additionalContext,
    );
    final tools = _functionMapper
        .toolsFromDefinitions(configuration.functionDefinitions)
        .map(_toolFor)
        .toList();

    // The first round sends the conversation; later rounds only send function
    // outputs and continue the same response chain.
    Object input = [
      for (final message in requestMessages)
        {
          'role': message.type == ChatMessageType.user ? 'user' : 'assistant',
          'content': message.message,
        },
    ];
    String? previousResponseId;

    for (var round = 0; round < AIConstants.maxToolRounds; round++) {
      final response = await _postJson('responses', {
        'model': modelName,
        'instructions': configuration.systemPrompt,
        'input': input,
        if (tools.isNotEmpty) 'tools': tools,
        'previous_response_id': ?previousResponseId,
      });

      final output = _maps(response['output']);
      final functionCalls = output
          .where((item) => item['type'] == 'function_call')
          .toList();
      if (functionCalls.isEmpty) {
        return _textFrom(output);
      }

      input = [for (final call in functionCalls) await _runFunctionCall(call)];
      previousResponseId = _idFrom(response);
    }

    throw AIProviderTooManyCallsFailure();
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _client.postJson(path, body) ??
          (throw AIProviderInvalidResponseFailure());
    } on DioException catch (error) {
      throw AIProviderRequestFailure(
        statusCode: error.response?.statusCode,
        message: _client.errorMessage(error),
      );
    }
  }

  Map<String, dynamic> _toolFor(Map<String, dynamic> definition) => {
    'type': 'function',
    ...definition,
    // Strict mode needs every property required and no extra properties, which
    // does not fit optional parameters. Without this the API tries to convert
    // the schema to strict mode and silently falls back if it cannot.
    'strict': false,
  };

  Future<Map<String, dynamic>> _runFunctionCall(
    Map<String, dynamic> call,
  ) async {
    final callId = call['call_id'];
    final name = call['name'];
    if (callId is! String || name is! String) {
      throw AIProviderMalformedToolCallFailure();
    }
    final result = await actionHandler.handle(
      FunctionCallResponse(name, _decodeArguments(call['arguments'])),
    );
    final payload = result.fold(
      (error) => {'error': error.toString()},
      (value) => {'result': value},
    );
    return {
      'type': 'function_call_output',
      'call_id': callId,
      'output': jsonEncode(payload),
    };
  }

  /// OpenAI sends function arguments as a JSON-encoded string.
  Map<String, dynamic> _decodeArguments(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : null;
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      throw AIProviderMalformedToolCallFailure();
    }
    throw AIProviderMalformedToolCallFailure();
  }

  String _idFrom(Map<String, dynamic> response) {
    final id = response['id'];
    if (id is String && id.isNotEmpty) {
      return id;
    }
    throw AIProviderInvalidResponseFailure();
  }

  String _textFrom(List<Map<String, dynamic>> output) {
    final text = [
      for (final item in output)
        if (item['type'] == 'message')
          for (final part in _maps(item['content']))
            if (part['type'] == 'output_text' && part['text'] is String)
              part['text'] as String,
    ];
    if (text.isEmpty) {
      throw AIProviderEmptyResponseFailure();
    }
    return text.join('\n');
  }

  List<Map<String, dynamic>> _maps(Object? list) =>
      list is List ? list.whereType<Map<String, dynamic>>().toList() : const [];
}
