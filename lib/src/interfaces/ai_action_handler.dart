import '../models/function_call_response.dart';
import 'ai_executable_action.dart';
import 'package:either_dart/either.dart';

/// Runs the functions an AI model asks the app to call.
abstract class AiActionHandler {
  final List<AiExecutableAction> actions;

  AiActionHandler({required this.actions});

  /// Runs the requested function and returns its output as text.
  ///
  /// A `Left` is not thrown: the provider services send its text back to the
  /// model, which can then explain the problem or retry with other arguments.
  Future<Either<Error, String>> handle(FunctionCallResponse response);
}
