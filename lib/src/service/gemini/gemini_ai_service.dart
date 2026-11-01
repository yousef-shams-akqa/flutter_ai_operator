import '../../constants/ai_constants.dart';
import '../../models/ai_configuration.dart';
import '../../models/chat_message.dart';
import '../../models/function_call_response.dart';
import '../../interfaces/ai_action_handler.dart';
import '../../interfaces/ai_service.dart';
import '../../helpers/json_schema_function_definition_mapper.dart';
import '../../helpers/prepare_chat_messages.dart';
import '../../failures/ai_provider_failure.dart';

import 'package:firebase_ai/firebase_ai.dart';

/// Talks to Gemini through the Firebase AI SDK, which runs the chat session.
class GeminiAIService implements AIService {
  final GenerativeModel model;
  @override
  final String modelName;
  @override
  final AIConfiguration configuration;
  @override
  final AiActionHandler actionHandler;

  /// Uses [model] when supplied; otherwise builds one from the configuration.
  /// An injected model must already use the requested model name and settings.
  GeminiAIService({
    required this.modelName,
    required this.configuration,
    required this.actionHandler,
    GenerativeModel? model,
  }) : model = model ?? _createModel(modelName, configuration);

  static const _functionDefinitionMapper = JsonSchemaFunctionDefinitionMapper();

  static GenerativeModel _createModel(
    String modelName,
    AIConfiguration configuration,
  ) {
    final definitions = _functionDefinitionMapper.toolsFromDefinitions(
      configuration.functionDefinitions,
    );
    return FirebaseAI.googleAI().generativeModel(
      model: modelName,
      systemInstruction: Content.text(configuration.systemPrompt),
      tools: definitions.isEmpty
          ? null
          : [
              Tool.functionDeclarations(
                definitions.map(_JsonFunctionDeclaration.new).toList(),
              ),
            ],
    );
  }

  @override
  Future<String> send(List<ChatMessage> messages, {String? appContext}) async {
    final requestMessages = prepareChatMessages(
      messages,
      appContext: appContext,
    );
    try {
      final chatHistoryContent = requestMessages
          .take(requestMessages.length - 1)
          .map(chatMessageToModelContent)
          .toList();
      final aiModelChat = model.startChat(history: chatHistoryContent);
      var aiResponse = await aiModelChat.sendMessage(
        Content.text(requestMessages.last.message),
      );

      for (var round = 0; aiResponse.functionCalls.isNotEmpty; round++) {
        if (round >= AIConstants.maxToolRounds) {
          throw AIProviderTooManyCallsFailure();
        }
        final functionResponseParts = <FunctionResponse>[];

        for (final call in aiResponse.functionCalls) {
          final functionCallResponse = FunctionCallResponse(
            call.name,
            call.args,
          );
          final actionResult = await actionHandler.handle(functionCallResponse);
          final actionResultPayload = actionResult.fold(
            (error) => {'error': error.toString()},
            (value) => {'result': value},
          );

          functionResponseParts.add(
            FunctionResponse(call.name, actionResultPayload, id: call.id),
          );
        }

        aiResponse = await aiModelChat.sendMessage(
          Content.functionResponses(functionResponseParts),
        );
      }

      return aiResponse.text ?? (throw AIProviderEmptyResponseFailure());
    } on FirebaseAIException catch (error) {
      throw AIProviderRequestFailure(message: error.message);
    } on FirebaseAISdkException {
      throw AIProviderInvalidResponseFailure();
    }
  }

  Content chatMessageToModelContent(ChatMessage chatMessage) {
    return switch (chatMessage.type) {
      ChatMessageType.user => Content.text(chatMessage.message),
      ChatMessageType.model => Content.model([TextPart(chatMessage.message)]),
    };
  }
}

/// Sends a tool from [JsonSchemaFunctionDefinitionMapper] to Gemini unchanged.
///
/// The SDK only builds declarations from its own typed schemas, so this
/// replaces the generated JSON with the shared one. Only `Tool.toJson` reads
/// a declaration, so overriding `toJson` is enough.
class _JsonFunctionDeclaration extends FunctionDeclaration {
  final Map<String, dynamic> _definition;

  static const _nameKey = 'name';
  static const _descriptionKey = 'description';
  static const _parametersKey = 'parameters';
  static const _parametersJsonSchemaKey = 'parametersJsonSchema';

  _JsonFunctionDeclaration(this._definition)
    : super(
        _definition[_nameKey] as String,
        _definition[_descriptionKey] as String,
        parameters: const {},
      );

  @override
  Map<String, Object?> toJson() => {
    _nameKey: _definition[_nameKey],
    _descriptionKey: _definition[_descriptionKey],
    _parametersJsonSchemaKey: _definition[_parametersKey],
  };
}
