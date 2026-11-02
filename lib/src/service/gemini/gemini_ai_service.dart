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

/// Talks to the Gemini [generateContent](https://ai.google.dev/api/generate-content) API.
class GeminiAIService implements AIService {
  GeminiAIService({
    required String apiKey,
    required this.modelName,
    required this.configuration,
    required this.actionHandler,
    AIProviderClient? client,
  }) : _client =
           client ??
           AIProviderClient(
             baseUrl: 'https://generativelanguage.googleapis.com/v1beta/',
             headers: {'x-goog-api-key': apiKey},
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
    final declarations = _functionMapper
        .toolsFromDefinitions(configuration.functionDefinitions)
        .map(_declarationFor)
        .toList();

    // Gemini is stateless: every round resends the full conversation.
    final conversation = <Map<String, dynamic>>[
      for (final message in requestMessages) _contentFor(message),
    ];

    for (var round = 0; round < AIConstants.maxToolRounds; round++) {
      final response = await _postJson('models/$modelName:generateContent', {
        'systemInstruction': {
          'parts': [
            {'text': configuration.systemPrompt},
          ],
        },
        'contents': conversation,
        if (declarations.isNotEmpty)
          'tools': [
            {'functionDeclarations': declarations},
          ],
      });

      final modelContent = _modelContent(response);
      final parts = _parts(modelContent);
      final functionCalls = [
        for (final part in parts)
          if (part['functionCall'] is Map<String, dynamic>)
            part['functionCall'] as Map<String, dynamic>,
      ];
      if (functionCalls.isEmpty) {
        return _textFrom(parts);
      }

      conversation
        ..add(modelContent)
        ..add({
          'role': 'user',
          'parts': [
            for (final call in functionCalls) await _runFunctionCall(call),
          ],
        });
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

  Map<String, dynamic> _contentFor(ChatMessage message) => {
    'role': message.type == ChatMessageType.user ? 'user' : 'model',
    'parts': [
      {'text': message.message},
    ],
  };

  Map<String, dynamic> _declarationFor(Map<String, dynamic> definition) => {
    'name': definition['name'],
    'description': definition['description'],
    'parametersJsonSchema': definition['parameters'],
  };

  Future<Map<String, dynamic>> _runFunctionCall(
    Map<String, dynamic> call,
  ) async {
    final name = call['name'];
    final args = call['args'];
    if (name is! String || args is! Map<String, dynamic>) {
      throw AIProviderMalformedToolCallFailure();
    }
    final result = await actionHandler.handle(FunctionCallResponse(name, args));
    final payload = result.fold(
      (error) => {'error': error.toString()},
      (value) => {'result': value},
    );
    return {
      'functionResponse': {
        if (call['id'] is String) 'id': call['id'],
        'name': name,
        'response': payload,
      },
    };
  }

  Map<String, dynamic> _modelContent(Map<String, dynamic> response) {
    final candidates = response['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw AIProviderEmptyResponseFailure();
    }
    final content = candidates.first['content'];
    if (content is! Map<String, dynamic>) {
      throw AIProviderInvalidResponseFailure();
    }
    return content;
  }

  String _textFrom(List<Map<String, dynamic>> parts) {
    final text = [
      for (final part in parts)
        if (part['text'] is String) part['text'] as String,
    ];
    if (text.isEmpty) {
      throw AIProviderEmptyResponseFailure();
    }
    return text.join('\n');
  }

  List<Map<String, dynamic>> _parts(Map<String, dynamic> content) {
    final parts = content['parts'];
    return parts is List
        ? parts.whereType<Map<String, dynamic>>().toList()
        : const [];
  }
}
