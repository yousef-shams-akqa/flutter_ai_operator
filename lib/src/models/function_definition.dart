
/// Describes an app function that a supported AI provider may call.
class FunctionDefinition {
  const FunctionDefinition({
    required this.name,
    required this.description,
    this.parameters = const [],
    this.optionalParameters = const [],
  });

  final String name;
  final String description;

  final List<FunctionParameter> parameters;

  /// Parameter [FunctionParameter.key] values that are not required.
  final List<String> optionalParameters;

  FunctionDefinition copyWith({
    String? name,
    String? description,
    List<FunctionParameter>? parameters,
    List<String>? optionalParameters,
  }) {
    return FunctionDefinition(
      name: name ?? this.name,
      description: description ?? this.description,
      parameters: parameters ?? this.parameters,
      optionalParameters: optionalParameters ?? this.optionalParameters,
    );
  }
}

/// Named function argument: parameter key plus its [FunctionParameterValue].
class FunctionParameter {
  const FunctionParameter({
    required this.key,
    required this.value,
  });

  final String key;
  final FunctionParameterValue value;

  FunctionParameter copyWith({
    String? key,
    FunctionParameterValue? value,
  }) {
    return FunctionParameter(
      key: key ?? this.key,
      value: value ?? this.value,
    );
  }
}

/// JSON Schema parameter types shared by supported provider adapters.
enum FunctionParameterType {
  string,
  number,
  integer,
  boolean,
}

/// Schema metadata for one function argument (type, description, allowed values).
class FunctionParameterValue {
  const FunctionParameterValue({
    required this.type,
    required this.description,
    this.possibleValues = const [],
  });

  final FunctionParameterType type;
  final String description;

  /// When non-empty, constrains the value (mapped to JSON Schema `enum` for strings).
  final List<String> possibleValues;

  FunctionParameterValue copyWith({
    FunctionParameterType? type,
    String? description,
    List<String>? possibleValues,
  }) {
    return FunctionParameterValue(
      type: type ?? this.type,
      description: description ?? this.description,
      possibleValues: possibleValues ?? this.possibleValues,
    );
  }
}
