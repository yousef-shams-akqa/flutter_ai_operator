import 'dart:io';

import 'package:flutter_ai_operator/flutter_ai_operator.dart';

// 0. Define the function definitions.
const addNumbersFunctionName = 'add_numbers';
const functionDefinitionList = [
  FunctionDefinition(
    name: addNumbersFunctionName,
    description: 'Adds two numbers and returns their sum.',
    parameters: [
      FunctionParameter(
        key: 'firstNumber',
        value: FunctionParameterValue(
          type: FunctionParameterType.number,
          description: 'The first number.',
        ),
      ),
      FunctionParameter(
        key: 'secondNumber',
        value: FunctionParameterValue(
          type: FunctionParameterType.number,
          description: 'The second number.',
        ),
      ),
    ],
  ),
];

// 1. Implement the logic your AI is allowed to call.
class AddNumbersAction implements AiExecutableAction<AddNumbersInput, num, Error> {
  @override
  Future<Either<Error, num>> execute(AddNumbersInput input) async =>
      Right(input.numbers.fold<num>(0, (sum, number) => sum + number));
}

// 2. Validate tool calls and route them to your action.
class CalculatorActionHandler extends AiActionHandler {
  CalculatorActionHandler(List<AiExecutableAction> actions)
    : super(actions: actions);

  @override
  Future<Either<Error, String>> handle(FunctionCallResponse response) async {
    if (response.functionName != addNumbersFunctionName) {
      return Left(ArgumentError('Unknown function: ${response.functionName}'));
    }

    final action = actions.whereType<AddNumbersAction>().firstOrNull;
    if (action == null) {
      return Left(
        StateError('No action registered for $addNumbersFunctionName.'),
      );
    }

    final input = AddNumbersInput.fromJson(response.functionArgs);
    if (input.isLeft) {
      return Left(input.left);
    }

    final result = await action.execute(input.right);
    return result.map((sum) => sum.toString());
  }
}

Future<void> main() async {
  // 3. Supply credentials when running; keep them out of this file.
  const apiKey = String.fromEnvironment('OPENAI_API_KEY');
  if (apiKey.trim().isEmpty) {
    throw StateError('Pass --dart-define=OPENAI_API_KEY=your-key.');
  }

  // 4. Describe the same function and arguments to the model.
  const configuration = AIConfiguration(
    systemPrompt: 'Always use add_numbers for addition. Reply with the result.',
    functionDefinitions: functionDefinitionList,
  );

  // 5. Connect the provider, function definitions, and action handler.
  final ai = AIServiceFactory.create(
    provider: AIProvider.openAI,
    apiKey: apiKey,
    modelName: const String.fromEnvironment('OPENAI_MODEL'),
    configuration: configuration,
    actionHandler: CalculatorActionHandler([AddNumbersAction()]),
  );

  // 6. Keep the conversation yourself, ending with the user's request.
  final messages = [ChatMessage.user('What is 12 plus 30?')];

  try {
    // 7. The package runs requested tools before returning the final reply.
    final reply = await ai.send(messages);
    messages.add(ChatMessage.model(reply));
    stdout.writeln('AI: $reply');
  } on AIProviderFailure catch (failure) {
    // 8. Surface failures instead of returning an empty or fake answer.
    stderr.writeln('AI request failed: ${failure.reason} (${failure.code}).');
    rethrow;
  }
}


// Parse model arguments into an immutable action input.
class AddNumbersInput {
  AddNumbersInput(this.numbers);

  final List<num> numbers;

  static Either<Error, AddNumbersInput> fromJson(Map<String, dynamic> json) {
    final firstNumber = json['firstNumber'];
    final secondNumber = json['secondNumber'];
    if (firstNumber is! num || secondNumber is! num) {
      return Left(
        ArgumentError('firstNumber and secondNumber must both be numbers.'),
      );
    }

    return Right(AddNumbersInput([firstNumber, secondNumber]));
  }
}