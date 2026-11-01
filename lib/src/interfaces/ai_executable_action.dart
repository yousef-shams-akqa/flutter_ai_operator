import 'package:either_dart/either.dart';

/// One app capability an AI model can call, such as a use case.
///
/// It only knows [Input]. Turning the model's JSON arguments into [Input] is
/// the action handler's job, and the matching `FunctionDefinition` (in
/// `shared/ai`) must describe the same arguments.
abstract class AiExecutableAction<Input, Output, Failure extends Error> {
  /// The [Output] is turned into text with `toString()` for the model.
  Future<Either<Failure, Output>> execute(Input input);
}
