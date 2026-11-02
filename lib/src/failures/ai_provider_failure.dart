/// An AI request has invalid input, failed, or returned something unusable.
///
/// Throw one of the subclasses below instead of this class directly.
class AIProviderFailure extends Error {
  AIProviderFailure(this.code, this.reason, {this.message});

  final int code;

  /// Stable identifier such as `TOO_MANY_CALLS`.
  final String reason;

  /// Extra detail for people, set only when there is some (for example the
  /// provider's own error text). Do not branch on it.
  final String? message;

  @override
  String toString() =>
      'AIProviderFailure($code): $reason${message == null ? '' : ' - $message'}';
}

/// The request failed. [code] is the HTTP status, or 0 when there is none
/// (offline or timeout). [message] is the
/// provider's error text if any.
class AIProviderRequestFailure extends AIProviderFailure {
  AIProviderRequestFailure({int? statusCode, super.message})
    : super(statusCode ?? 0, 'REQUEST_FAILED');
}

/// The model kept requesting tools past `AIConstants.maxToolRounds`.
class AIProviderTooManyCallsFailure extends AIProviderFailure {
  AIProviderTooManyCallsFailure() : super(1001, 'TOO_MANY_CALLS');
}

/// A tool call from the model was missing fields or had unreadable arguments.
class AIProviderMalformedToolCallFailure extends AIProviderFailure {
  AIProviderMalformedToolCallFailure() : super(1002, 'MALFORMED_TOOL_CALL');
}

/// The model finished without any text to show.
class AIProviderEmptyResponseFailure extends AIProviderFailure {
  AIProviderEmptyResponseFailure() : super(1003, 'EMPTY_RESPONSE');
}

/// The response body was not the JSON shape the provider documents.
class AIProviderInvalidResponseFailure extends AIProviderFailure {
  AIProviderInvalidResponseFailure() : super(1004, 'INVALID_RESPONSE');
}

/// The conversation is empty or does not end with a non-blank user message.
class AIProviderInvalidInputFailure extends AIProviderFailure {
  AIProviderInvalidInputFailure() : super(1005, 'INVALID_INPUT');
}
