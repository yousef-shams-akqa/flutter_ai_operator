import '../failures/ai_provider_failure.dart';
import '../models/chat_message.dart';

/// Validates and snapshots the conversation before a provider starts work.
///
/// Context is attached only to the copied final user message. The caller's
/// messages remain the source of truth for stored conversation state.
List<ChatMessage> prepareChatMessages(
  List<ChatMessage> messages, {
  String? appContext,
}) {
  final requestMessages = List<ChatMessage>.of(messages);
  if (requestMessages.isEmpty ||
      requestMessages.last.type != ChatMessageType.user ||
      requestMessages.last.message.trim().isEmpty) {
    throw AIProviderInvalidInputFailure();
  }

  if (appContext != null && appContext.isNotEmpty) {
    final lastMessageWithContext = ChatMessage.user(requestMessages.last.message + appContext);
    requestMessages[requestMessages.length - 1] = lastMessageWithContext;
  }

  return List<ChatMessage>.unmodifiable(requestMessages);
}
