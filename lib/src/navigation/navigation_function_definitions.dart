import '../models/function_definition.dart';
import 'navigation_input.dart';
import 'navigation_method.dart';

/// Tool definitions for every [NavigationMethod], matching what
/// [NavigationInput.fromArgs] reads.
///
/// [locations] limits `location` to these route paths, for example
/// `router.routePaths()`. When empty, the model may send any path.
List<FunctionDefinition> navigationFunctionDefinitions({
  List<String> locations = const [],
}) {
  final locationParameters = [
    FunctionParameter(
      key: NavigationInput.locationKey,
      value: FunctionParameterValue(
        type: FunctionParameterType.string,
        description:
            'Route path to open, such as /products/:productId. Keep '
            ':placeholders and fill them with pathParameters.',
        possibleValues: locations,
      ),
    ),
    const FunctionParameter(
      key: NavigationInput.pathParametersKey,
      value: FunctionParameterValue(
        type: FunctionParameterType.object,
        description:
            'Values for the :placeholders in location, keyed by placeholder '
            'name, such as {"productId": "42"}.',
        additionalProperties: FunctionParameterValue(
          type: FunctionParameterType.string,
          description: 'Value for one route placeholder.',
        ),
      ),
    ),
    const FunctionParameter(
      key: NavigationInput.queryParametersKey,
      value: FunctionParameterValue(
        type: FunctionParameterType.object,
        description: 'Query string values to add to the location, by name.',
        additionalProperties: FunctionParameterValue(
          type: FunctionParameterType.string,
          description: 'Value for one query parameter.',
        ),
      ),
    ),
  ];
  const optionalParameters = [
    NavigationInput.pathParametersKey,
    NavigationInput.queryParametersKey,
  ];

  final resetStackTo = NavigationMethod.resetStackTo.functionName;
  final pushScreen = NavigationMethod.push.functionName;

  return [
    FunctionDefinition(
      name: resetStackTo,
      description:
          'Don\'t use this unless you intend to switch go router\'s shell tabs or clear the entire current stack. '
          'Clears the all screens on the stack and shows the added location as the first screen on the stack. '
          'Use $pushScreen instead when the user should be able to come back.',
      parameters: locationParameters,
      optionalParameters: optionalParameters,
    ),
    FunctionDefinition(
      name: pushScreen,
      description:
          'Opens the location on top of the current screen, so the user can '
          'come back to it. Use it for details and temporary views. Use '
          '$resetStackTo to switch sections.',
      parameters: locationParameters,
      optionalParameters: optionalParameters,
    ),
    FunctionDefinition(
      name: NavigationMethod.replace.functionName,
      description:
          'Replaces the current screen with the location, without adding to '
          'the back history. Use it when the user should not return to the '
          'current screen.',
      parameters: locationParameters,
      optionalParameters: optionalParameters,
    ),
    FunctionDefinition(
      name: NavigationMethod.pop.functionName,
      description:
          'Closes the current screen and returns to the previous one. Fails '
          'when there is no previous screen.',
    ),
  ];
}
