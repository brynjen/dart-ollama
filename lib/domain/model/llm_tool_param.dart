class LLMToolParam {
  LLMToolParam({
    required this.name,
    required this.type,
    required this.description,
    this.isRequired = false,
    this.enums = const [],
  });

  /// Name of the parameter
  final String name;

  /// Type, like in string, integer, double etc
  final String type;

  /// A good description of what this parameter entails for the LLM
  final String description;

  /// Whether this parameter is a required input to achieve output
  final bool isRequired;

  /// Possible enum return values (like celsius and fahrenheit)
  final List<String> enums;
}
