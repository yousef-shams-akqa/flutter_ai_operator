import 'package:flutter_app_copilot/flutter_app_copilot.dart';
import 'package:flutter_app_copilot/src/helpers/json_schema_function_definition_mapper.dart';
// Tests intentionally live under lib; flutter_test remains a dev dependency.
// ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = JsonSchemaFunctionDefinitionMapper();
  const definition = FunctionDefinition(
    name: 'set_mode',
    description: 'Changes the display mode',
    parameters: [
      FunctionParameter(
        key: 'mode',
        value: FunctionParameterValue(
          type: FunctionParameterType.string,
          description: 'Display mode',
          possibleValues: ['light', 'dark'],
        ),
      ),
      FunctionParameter(
        key: 'enabled',
        value: FunctionParameterValue(
          type: FunctionParameterType.boolean,
          description: 'Whether it is enabled',
        ),
      ),
    ],
    optionalParameters: ['enabled'],
  );

  test('maps optional arguments, enum values and function metadata', () {
    expect(mapper.toolsFromDefinitions([definition]), [
      {
        'name': 'set_mode',
        'description': 'Changes the display mode',
        'parameters': {
          'type': 'object',
          'properties': {
            'mode': {
              'type': 'string',
              'description': 'Display mode',
              'enum': ['light', 'dark'],
            },
            'enabled': {
              'type': 'boolean',
              'description': 'Whether it is enabled',
            },
          },
          'required': ['mode'],
        },
      },
    ]);
  });

  test('supports zero-argument functions and no configured tools', () {
    expect(mapper.toolsFromDefinitions([]), isEmpty);
    expect(
      mapper.toolsFromDefinitions([
        const FunctionDefinition(name: 'refresh', description: 'Refreshes'),
      ]).single['parameters'],
      {'type': 'object', 'properties': <String, dynamic>{}},
    );
  });

  test('maps object arguments with typed additional properties', () {
    const pathParameters = FunctionParameterValue(
      type: FunctionParameterType.object,
      description: 'Route placeholder values',
      additionalProperties: FunctionParameterValue(
        type: FunctionParameterType.string,
        description: 'A placeholder value',
      ),
    );
    final schema = mapper.toolsFromDefinitions([
      const FunctionDefinition(
        name: 'navigate',
        description: 'Navigates',
        parameters: [
          FunctionParameter(key: 'pathParameters', value: pathParameters),
        ],
      ),
    ]).single['parameters'];

    expect((schema['properties'] as Map)['pathParameters'], {
      'type': 'object',
      'description': 'Route placeholder values',
      'additionalProperties': {
        'type': 'string',
        'description': 'A placeholder value',
      },
    });
  });

  test('copyWith keeps additionalProperties unless asked to clear it', () {
    const withSchema = FunctionParameterValue(
      type: FunctionParameterType.object,
      description: 'Map',
      additionalProperties: FunctionParameterValue(
        type: FunctionParameterType.number,
        description: 'Value',
      ),
    );
    final cleared = withSchema.copyWith(clearAdditionalProperties: true);

    expect(
      withSchema.copyWith(description: 'Other').additionalProperties,
      isNotNull,
    );
    expect(cleared.additionalProperties, isNull);
  });

  test('omits required when all arguments are optional', () {
    final schema = mapper.toolsFromDefinitions([
      definition.copyWith(optionalParameters: ['mode', 'enabled']),
    ]).single['parameters'];

    expect(schema, isNot(contains('required')));
    expect((schema['properties'] as Map).keys, ['mode', 'enabled']);
  });
}
