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

/// Talks to the Claude Messages API and runs its tool-use loop.
class ClaudeAIService implements AIService {
  ClaudeAIService({
    required String apiKey,
    required this.modelName,
    required this.configuration,
    required this.actionHandler,
    AIProviderClient? client,
  }) : _client =
           client ??
           AIProviderClient(
             baseUrl: 'https://api.anthropic.com/v1/',
             headers: {'x-api-key': apiKey, 'anthropic-version': '2026-10-21'},
           );

  static const _maxTokens = 2048;
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

    // Claude is stateless: every round resends the whole conversation.
    final conversation = <Map<String, dynamic>>[
      for (final message in requestMessages)
        {
          'role': message.type == ChatMessageType.user ? 'user' : 'assistant',
          'content': message.message,
        },
    ];

    for (var round = 0; round < AIConstants.maxToolRounds; round++) {
      final response = await _postJson('messages', {
        'model': modelName,
        'max_tokens': _maxTokens,
        'system': configuration.systemPrompt,
        'messages': conversation,
        if (tools.isNotEmpty) 'tools': tools,
      });

      final content = _maps(response['content']);
      final toolCalls = content
          .where((block) => block['type'] == 'tool_use')
          .toList();
      if (toolCalls.isEmpty) {
        return _textFrom(content);
      }

      conversation
        ..add({'role': 'assistant', 'content': content})
        ..add({
          'role': 'user',
          'content': [for (final call in toolCalls) await _runToolCall(call)],
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

  Map<String, dynamic> _toolFor(Map<String, dynamic> definition) => {
    'name': definition['name'],
    'description': definition['description'],
    'input_schema': definition['parameters'],
  };

  Future<Map<String, dynamic>> _runToolCall(Map<String, dynamic> call) async {
    final id = call['id'];
    final name = call['name'];
    final input = call['input'];
    if (id is! String || name is! String || input is! Map<String, dynamic>) {
      throw AIProviderMalformedToolCallFailure();
    }
    final result = await actionHandler.handle(
      FunctionCallResponse(name, input),
    );
    final payload = result.fold(
      (error) => {'error': error.toString()},
      (value) => {'result': value},
    );
    return {
      'type': 'tool_result',
      'tool_use_id': id,
      'content': jsonEncode(payload),
    };
  }

  String _textFrom(List<Map<String, dynamic>> content) {
    final text = [
      for (final block in content)
        if (block['type'] == 'text' && block['text'] is String)
          block['text'] as String,
    ];
    if (text.isEmpty) {
      throw AIProviderEmptyResponseFailure();
    }
    return text.join('\n');
  }

  List<Map<String, dynamic>> _maps(Object? list) =>
      list is List ? list.whereType<Map<String, dynamic>>().toList() : const [];
}
