
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_app_copilot/flutter_app_copilot.dart';
import 'package:go_router/go_router.dart' show GoRoute, GoRouter;

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
  Future<Either<Error, num>> execute(AddNumbersInput input) async {
    try {
      final result = input.firstNumber + input.secondNumber;
      return Right(result);
    } catch (e) {
      return Left(Error());
    }
  }
}

// 2. Validate tool calls and route them to your action.
class AppActionHandler extends AiActionHandler {
  AppActionHandler(List<AiExecutableAction> actions) : super(actions: actions);

  @override
  Future<Either<Error, String>> handle(FunctionCallResponse response) async {
    // Handle the add numbers function.
    // Ideally we should switch over an enum of your function names here
    if (response.functionName == addNumbersFunctionName) {
      final input = AddNumbersInput.fromJson(response.functionArgs);
      final addNumbersAction = actions.whereType<AddNumbersAction>().first;
      final result = await addNumbersAction.execute(input);
      return result.map((sum) => sum.toString());
    }

    // Handle the navigation functions the package provides.
    final method = NavigationMethod.fromFunctionName(response.functionName);
    if (method != null) {
      final input = NavigationInput.fromArgs(method, response.functionArgs);
      if (input.isLeft) return Left(input.left);
      return actions.whereType<GoRouterNavigationAction>().first.execute(input.right);
    }

    // Handle other functions here (if any)...
    // ...

    // If no action is registered for the function, return an error.
    return Left(StateError('No action registered for ${response.functionName}.'));
  }
}

Future<void> main() async {
  // 3. Supply credentials when running; keep them out of this file.
  const apiKey = String.fromEnvironment('OPENAI_API_KEY');

  // 4. Describe the same function and arguments to the model.
  // The router adds the navigation tools and tells the model where the user is.
  final configuration = AIConfiguration(
    systemPrompt: 'Always use add_numbers for addition. Reply with the result.',
    functionDefinitions: [
      ...functionDefinitionList,
      ...navigationFunctionDefinitions(locations: exampleRouter.routePaths()),
    ],
    contextSources: [GoRouterContextSource(exampleRouter)],
  );

  // 5. Connect the provider, function definitions, and action handler.
  final ai = AIServiceFactory.create(
    provider: AIProvider.openAI,
    apiKey: apiKey,
    modelName: const String.fromEnvironment('OPENAI_MODEL'),
    configuration: configuration,
    actionHandler: AppActionHandler([
      AddNumbersAction(),
      GoRouterNavigationAction(exampleRouter),
    ]),
  );

  // 6. Keep the conversation yourself, ending with the user's request.
  final messages = [ChatMessage.user('What is 12 plus 30?')];

  try {
    // 7. The package runs requested tools and actions before returning the final reply.
    final reply = await ai.send(messages);
    messages.add(ChatMessage.model(reply));
    // Use the updated messages list to update the UI.
  } on AIProviderFailure {
    // 8. Surface failures instead of returning an empty or fake answer.
    rethrow;
  }
}


// Parse model arguments into an immutable action input.
class AddNumbersInput {
  final num firstNumber;
  final num secondNumber;
  AddNumbersInput(this.firstNumber, this.secondNumber);


  factory AddNumbersInput.fromJson(Map<String, dynamic> json) {
    final firstNumber = num.tryParse(json['firstNumber']) ?? 0;
    final secondNumber = num.tryParse(json['secondNumber']) ?? 0;
    return AddNumbersInput(firstNumber, secondNumber);
  }
}

// A small router for the example. Use your app's own router instead, and mount
// it with `MaterialApp.router(routerConfig: ...)`: the model's navigation
// context is only available once the router is on screen.
final exampleRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
    GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
    GoRoute(path: '/products/:productId', builder: (_, _) => const SizedBox()),
  ],
);
