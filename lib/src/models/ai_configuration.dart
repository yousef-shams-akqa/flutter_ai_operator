import '../constants/ai_constants.dart';
import 'function_definition.dart';

/// Runtime configuration for an AI session: instructions and available tools.
class AIConfiguration {
  const AIConfiguration({
    this.systemPrompt = AIConstants.systemPrompt,
    this.functionDefinitions = const [],
  });

  /// Instructions sent to the model on every request.
  final String systemPrompt;

  /// Functions the model may call. Must match what the action handler can run.
  final List<FunctionDefinition> functionDefinitions;

  AIConfiguration copyWith({
    String? systemPrompt,
    List<FunctionDefinition>? functionDefinitions,
  }) {
    return AIConfiguration(
      systemPrompt: systemPrompt ?? this.systemPrompt,
      functionDefinitions: functionDefinitions ?? this.functionDefinitions,
    );
  }
}
