/// Supplies live app state to the model, for example the current screen.
///
/// Register sources in `AIConfiguration.contextSources`. Every `send()` calls
/// [read] again, so the text always reflects the app at that moment.
abstract interface class AppContextSource {
  /// The text appended to the user's latest message.
  ///
  /// Start it with a line break so it stays apart from the user's words.
  String read();
}
