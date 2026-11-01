/// A function call response from the model.
///
/// [functionName] is the name of the function to call.
/// [functionArgs] come from the model and are untrusted: they may be missing
/// or have the wrong types.
class FunctionCallResponse {
  final String functionName;
  final Map<String, dynamic> functionArgs;

  FunctionCallResponse(this.functionName, this.functionArgs);
}
