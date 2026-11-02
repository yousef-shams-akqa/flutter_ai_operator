import '../interfaces/ai_action_handler.dart';
import '../models/ai_configuration.dart';
import '../models/ai_provider.dart';
import '../interfaces/ai_service.dart';
import 'claude/claude_ai_service.dart';
import 'gemini/gemini_ai_service.dart';
import 'openai/openai_ai_service.dart';

/// Creates a provider-specific [AIService] from runtime configuration.
abstract final class AIServiceFactory {
  /// Builds the service for [provider]. A blank [modelName] uses the
  /// provider's default.
  ///
  /// [apiKey] must be non-empty for every provider (throws [StateError] when
  /// blank). Every call returns a new service; keep the one the app should use.
  static AIService create({
    required AIProvider provider,
    required AIConfiguration configuration,
    required AiActionHandler actionHandler,
    required String apiKey,
    String? modelName,
  }) {
    final isValidModelName = modelName?.trim().isNotEmpty ?? false;
    return switch (provider) {
      AIProvider.gemini => GeminiAIService(
        apiKey: _requireApiKey(apiKey, provider),
        modelName: isValidModelName
            ? modelName!.trim()
            : AIProvider.gemini.defaultModelName,
        configuration: configuration,
        actionHandler: actionHandler,
      ),
      AIProvider.openAI => OpenAIService(
        apiKey: _requireApiKey(apiKey, provider),
        modelName: isValidModelName
            ? modelName!.trim()
            : AIProvider.openAI.defaultModelName,
        configuration: configuration,
        actionHandler: actionHandler,
      ),
      AIProvider.claude => ClaudeAIService(
        apiKey: _requireApiKey(apiKey, provider),
        modelName: isValidModelName
            ? modelName!.trim()
            : AIProvider.claude.defaultModelName,
        configuration: configuration,
        actionHandler: actionHandler,
      ),
    };
  }

  static String _requireApiKey(String apiKey, AIProvider provider) {
    final trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw StateError('An API key is required for ${provider.name}.');
    }
    return trimmedKey;
  }
}
