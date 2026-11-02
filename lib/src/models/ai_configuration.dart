import '../constants/ai_constants.dart';
import '../interfaces/app_context_source.dart';
import 'function_definition.dart';

/// Runtime configuration for an AI session: instructions, tools, and context.
class AIConfiguration {
  const AIConfiguration({
    this.systemPrompt = AIConstants.systemPrompt,
    this.functionDefinitions = const [],
    this.contextSources = const [],
  });

  /// Instructions sent to the model on every request.
  final String systemPrompt;

  /// Functions the model may call. Must match what the action handler can run.
  final List<FunctionDefinition> functionDefinitions;

  /// Live app state added to the user's latest message on every request, in
  /// list order.
  final List<AppContextSource> contextSources;

  AIConfiguration copyWith({
    String? systemPrompt,
    List<FunctionDefinition>? functionDefinitions,
    List<AppContextSource>? contextSources,
  }) {
    return AIConfiguration(
      systemPrompt: systemPrompt ?? this.systemPrompt,
      functionDefinitions: functionDefinitions ?? this.functionDefinitions,
      contextSources: contextSources ?? this.contextSources,
    );
  }
}
