import '../models/function_definition.dart';

/// Maps app definitions to a provider-neutral JSON function representation.
///
/// Each item is `{name, description, parameters}`, where `parameters` is a
/// JSON Schema object. Every parameter not listed in
/// `FunctionDefinition.optionalParameters` is marked required. Each provider
/// service wraps the item in its own tool envelope (OpenAI adds `type`, Claude
/// renames `parameters` to `input_schema`, Gemini maps `parameters` to
/// `parametersJsonSchema`).
class JsonSchemaFunctionDefinitionMapper {
  const JsonSchemaFunctionDefinitionMapper();

  List<Map<String, dynamic>> toolsFromDefinitions(
    List<FunctionDefinition> definitions,
  ) {
    return definitions.map(_toJsonFunctionDefinition).toList();
  }

  Map<String, dynamic> _toJsonFunctionDefinition(
    FunctionDefinition definition,
  ) {
    return {
      'name': definition.name,
      'description': definition.description,
      'parameters': _parametersSchema(definition),
    };
  }

  Map<String, dynamic> _parametersSchema(FunctionDefinition definition) {
    final properties = <String, dynamic>{
      for (final parameter in definition.parameters)
        parameter.key: _schemaFor(parameter.value),
    };
    final required = definition.parameters
        .where(
          (parameter) => !definition.optionalParameters.contains(parameter.key),
        )
        .map((parameter) => parameter.key)
        .toList();

    return {
      'type': 'object',
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
    };
  }

  Map<String, dynamic> _schemaFor(FunctionParameterValue parameter) {
    final type = switch (parameter.type) {
      FunctionParameterType.string => 'string',
      FunctionParameterType.number => 'number',
      FunctionParameterType.integer => 'integer',
      FunctionParameterType.boolean => 'boolean',
    };
    return {
      'type': type,
      'description': parameter.description,
      if (parameter.possibleValues.isNotEmpty) 'enum': parameter.possibleValues,
    };
  }
}
