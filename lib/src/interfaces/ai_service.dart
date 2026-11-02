import '../models/ai_configuration.dart';
import 'ai_action_handler.dart';
import '../models/chat_message.dart';

/// One AI provider (Gemini, OpenAI, or Claude) behind a single contract.
///
/// Create instances with `AIServiceFactory`. The service holds no
/// conversation between calls; the caller passes the full conversation every time.
abstract class AIService {
  final String modelName;
  final AIConfiguration configuration;
  final AiActionHandler actionHandler;

  AIService({
    required this.modelName,
    required this.configuration,
    required this.actionHandler,
  });

  /// Sends [messages] and returns the model's final text reply.
  ///
  /// Runs any functions the model asks for through [actionHandler] and keeps
  /// going until the model answers with text. Messages must be ordered from
  /// oldest to newest and end with a non-empty user message. The service
  /// snapshots the list without changing it.
  ///
  /// The text of every `AIConfiguration.contextSources` entry is read now and
  /// appended only to the outgoing final message. [additionalContext] is
  /// optional extra text added after it, for one-off details.
  ///
  /// Throws `AIProviderInvalidInputFailure` before sending a request if the
  /// list is empty, ends with a model message, or ends with blank user text,
  /// and `AIProviderContextFailure` if a context source fails.
  /// Other `AIProviderFailure` subclasses describe provider failures, unusable
  /// responses, or too many consecutive tool rounds.
  Future<String> send(List<ChatMessage> messages, {String? additionalContext});
}
