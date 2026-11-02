/// Why a navigation tool call could not run.
enum NavigationFailureReason {
  /// The model's arguments were missing or had the wrong types.
  invalidInput,

  /// The location does not match any route in the router.
  unknownRoute,

  /// Pop was requested with no previous screen to go back to.
  nothingToPop,

  /// The router threw while navigating.
  routerError,
}

/// A navigation tool call that could not run.
///
/// Its [toString] is sent back to the model, so [message] says what to fix.
class NavigationFailure extends Error {
  NavigationFailure(
    this.reason,
    this.message, {
    this.cause,
    this.causeStackTrace,
  });

  final NavigationFailureReason reason;

  /// Detail for the model and for logs. Branch on [reason] instead.
  final String message;

  /// What the router threw, set only for [NavigationFailureReason.routerError].
  final Object? cause;

  final StackTrace? causeStackTrace;

  @override
  String toString() => 'NavigationFailure(${reason.name}): $message';
}
