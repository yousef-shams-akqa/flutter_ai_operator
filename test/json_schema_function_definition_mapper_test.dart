import 'package:flutter_ai_operator/flutter_ai_operator.dart';
import 'package:flutter_ai_operator/src/helpers/json_schema_function_definition_mapper.dart';
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

  test('omits required when all arguments are optional', () {
    final schema = mapper.toolsFromDefinitions([
      definition.copyWith(optionalParameters: ['mode', 'enabled']),
    ]).single['parameters'];

    expect(schema, isNot(contains('required')));
    expect((schema['properties'] as Map).keys, ['mode', 'enabled']);
  });
}
