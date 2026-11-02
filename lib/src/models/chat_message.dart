/// A message sent to or from the AI model.
class ChatMessage {
  final String message;
  final ChatMessageType type;

  ChatMessage({required this.message, required this.type});

  factory ChatMessage.user(String message) {
    return ChatMessage(message: message, type: ChatMessageType.user);
  }

  factory ChatMessage.model(String message) {
    return ChatMessage(message: message, type: ChatMessageType.model);
  }
}

enum ChatMessageType { user, model }
