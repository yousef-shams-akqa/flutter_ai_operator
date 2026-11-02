/// How a navigation tool call moves through the app. Each method is one tool.
enum NavigationMethod {
  /// Clears the screens opened on top and shows a location as the main screen
  /// (`GoRouter.go`). A tab keeps its own history.
  resetStackTo('resetStackTo'),

  /// Opens a location on top of the current screen (`GoRouter.push`).
  push('pushScreen'),

  /// Swaps the current screen for a location (`GoRouter.replace`).
  replace('replaceTopScreen'),

  /// Closes the current screen (`GoRouter.pop`).
  pop('popScreen');

  const NavigationMethod(this.functionName);

  /// Name of the tool the model calls for this method.
  final String functionName;

  /// The method for [functionName], or null when it is not a navigation tool.
  static NavigationMethod? fromFunctionName(String functionName) {
    for (final method in values) {
      if (method.functionName == functionName) return method;
    }
    return null;
  }
}
