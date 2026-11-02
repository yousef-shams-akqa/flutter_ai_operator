import '../failures/ai_provider_failure.dart';
import '../interfaces/app_context_source.dart';
import '../models/chat_message.dart';

/// Validates and snapshots the conversation before a provider starts work.
///
/// Context is attached only to the copied final user message: first the text
/// of every [contextSources] entry, then [additionalContext]. The caller's
/// messages
/// remain the source of truth for stored conversation state.
///
/// Throws [AIProviderInvalidInputFailure] for an unusable conversation and
/// [AIProviderContextFailure] when a context source fails.
List<ChatMessage> prepareChatMessages(
  List<ChatMessage> messages, {
  List<AppContextSource> contextSources = const [],
  String? additionalContext,
}) {
  final requestMessages = List<ChatMessage>.of(messages);
  if (requestMessages.isEmpty ||
      requestMessages.last.type != ChatMessageType.user ||
      requestMessages.last.message.trim().isEmpty) {
    throw AIProviderInvalidInputFailure();
  }

  final context = _readContext(contextSources) + (additionalContext ?? '');
  if (context.isNotEmpty) {
    requestMessages[requestMessages.length - 1] = ChatMessage.user(
      requestMessages.last.message + context,
    );
  }

  return List<ChatMessage>.unmodifiable(requestMessages);
}

String _readContext(List<AppContextSource> sources) {
  final context = StringBuffer();
  for (final source in sources) {
    try {
      context.write(source.read());
    } catch (error) {
      throw AIProviderContextFailure(message: '$error');
    }
  }
  return context.toString();
}
