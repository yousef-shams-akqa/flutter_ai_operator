/// Provider implementation available in the core AI layer.
enum AIProvider { gemini, openAI, claude }

extension AIProviderExtension on AIProvider {
  /// Model used when the caller does not choose one.
  String get defaultModelName => switch (this) {
    AIProvider.gemini => 'gemini-3.5-flash-lite',
    AIProvider.openAI => 'gpt-6-luna',
    AIProvider.claude => 'claude-sonnet-5-5',
  };
}
