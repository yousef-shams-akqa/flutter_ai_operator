import 'dart:convert';

import 'package:flutter_app_copilot/flutter_app_copilot.dart';
// The final SDK model requires its test factory to replace the transport.
// ignore: implementation_imports
import 'package:firebase_ai/src/base_model.dart' show createModelWithClient;
// ignore: implementation_imports
import 'package:firebase_ai/src/client.dart' show ApiClient;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_app_copilot/src/service/claude/claude_ai_service.dart';
import 'package:flutter_app_copilot/src/service/gemini/gemini_ai_service.dart';
import 'package:flutter_app_copilot/src/service/openai/openai_ai_service.dart';
import 'package:flutter_app_copilot/src/service/shared/ai_provider_client.dart';
// Tests intentionally live under lib; flutter_test remains a dev dependency.
// ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';

/// Each test owns its script and recorded requests; nothing is persisted.
class AIServiceFixture {
  AIServiceFixture(this.provider) {
    service = switch (provider) {
      AIProvider.openAI => OpenAIService(
        apiKey: 'test-key',
        modelName: 'test-model',
        configuration: _configuration,
        actionHandler: actionHandler,
        client: _ProviderClient(_respond),
      ),
      AIProvider.claude => ClaudeAIService(
        apiKey: 'test-key',
        modelName: 'test-model',
        configuration: _configuration,
        actionHandler: actionHandler,
        client: _ProviderClient(_respond),
      ),
      AIProvider.gemini => GeminiAIService(
        modelName: 'test-model',
        configuration: _configuration,
        actionHandler: actionHandler,
        model: createModelWithClient(
          app: _FirebaseApp(),
          location: 'global',
          model: 'test-model',
          useAgentPlatform: false,
          client: _GeminiClient(_respond),
        ),
      ),
    };
  }

  static const _configuration = AIConfiguration(
    functionDefinitions: [
      FunctionDefinition(
        name: 'save_value',
        description: 'Saves a value',
        parameters: [
          FunctionParameter(
            key: 'value',
            value: FunctionParameterValue(
              type: FunctionParameterType.string,
              description: 'Value to save',
            ),
          ),
        ],
      ),
    ],
  );

  final AIProvider provider;
  final actionHandler = TestActionHandler();
  late final AIService service;
  final responses = <Map<String, dynamic>>[];
  final requests = <Map<String, dynamic>>[];
  int _callCount = 0;

  Map<String, dynamic> toolReply() {
    final id = 'call-${_callCount++}';
    return switch (provider) {
      AIProvider.openAI => {
        'id': 'response-$id',
        'output': [
          {
            'type': 'function_call',
            'call_id': id,
            'name': 'save_value',
            'arguments': '{"value":"dark"}',
          },
        ],
      },
      AIProvider.claude => {
        'content': [
          {
            'type': 'tool_use',
            'id': id,
            'name': 'save_value',
            'input': {'value': 'dark'},
          },
        ],
      },
      AIProvider.gemini => {
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {
                  'functionCall': {
                    'id': id,
                    'name': 'save_value',
                    'args': {'value': 'dark'},
                  },
                },
              ],
            },
          },
        ],
      },
    };
  }

  Map<String, dynamic> textReply(String text) => switch (provider) {
    AIProvider.openAI => {
      'output': [
        {
          'type': 'message',
          'content': [
            {'type': 'output_text', 'text': text},
          ],
        },
      ],
    },
    AIProvider.claude => {
      'content': [
        {'type': 'text', 'text': text},
      ],
    },
    AIProvider.gemini => {
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              {'text': text},
            ],
          },
        },
      ],
    },
  };

  Map<String, dynamic> emptyReply() => switch (provider) {
    AIProvider.openAI => {'output': []},
    AIProvider.claude => {'content': []},
    AIProvider.gemini => {'candidates': []},
  };

  /// Normalizes the first outgoing request so contract tests cover every adapter.
  List<Map<String, dynamic>> get sentMessages {
    final body = requests.first;
    return switch (provider) {
      AIProvider.openAI => List<Map<String, dynamic>>.from(
        body['input'] as List,
      ),
      AIProvider.claude => List<Map<String, dynamic>>.from(
        body['messages'] as List,
      ),
      AIProvider.gemini => [
        for (final content in body['contents'] as List)
          {
            'role': content['role'] == 'model' ? 'assistant' : 'user',
            'content': (content['parts'] as List)
                .map((part) => part['text'] as String)
                .join(),
          },
      ],
    };
  }

  // Read the tool payload from the actual follow-up request. Missing or
  // malformed output fails the test rather than being replaced with a default.
  Map<String, dynamic> get toolResult {
    final body = requests[1];
    return switch (provider) {
      AIProvider.openAI =>
        jsonDecode(body['input'].single['output']) as Map<String, dynamic>,
      AIProvider.claude => jsonDecode(
        body['messages'].last['content'].single['content'],
      ) as Map<String, dynamic>,
      AIProvider.gemini =>
        body['contents'].last['parts'].single['functionResponse']['response']
            as Map<String, dynamic>,
    };
  }

  Map<String, dynamic> _respond(Map<String, dynamic> body) {
    requests.add(jsonDecode(jsonEncode(body)) as Map<String, dynamic>);
    if (responses.isEmpty) throw StateError('Unexpected AI provider request');
    return responses.removeAt(0);
  }
}

class TestActionHandler extends AiActionHandler {
  TestActionHandler() : super(actions: const []);

  Either<Error, String> result = const Right('saved');
  final calls = <FunctionCallResponse>[];

  @override
  Future<Either<Error, String>> handle(FunctionCallResponse response) async {
    calls.add(response);
    return result;
  }
}

class _ProviderClient extends Fake implements AIProviderClient {
  _ProviderClient(this.respond);
  final Map<String, dynamic> Function(Map<String, dynamic>) respond;

  @override
  Future<Map<String, dynamic>?> postJson(
    String path,
    Map<String, dynamic> body,
  ) async => respond(body);
}

class _GeminiClient extends Fake implements ApiClient {
  _GeminiClient(this.respond);
  final Map<String, dynamic> Function(Map<String, dynamic>) respond;

  @override
  Future<Map<String, Object?>> makeRequest(
    Uri uri,
    Map<String, Object?> body,
  ) async => respond(body);
}

class _FirebaseApp extends Fake implements FirebaseApp {
  @override
  FirebaseOptions get options => const FirebaseOptions(
    apiKey: 'test-key',
    appId: 'test-app',
    messagingSenderId: 'test-sender',
    projectId: 'test-project',
  );
}
