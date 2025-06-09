class LLMToolParam {
  LLMToolParam({
    required this.name,
    required this.type,
    required this.description,
    this.isRequired = false,
    this.enums = const [],
    this.items,
    this.minItems,
    this.maxItems,
    this.uniqueItems,
  });

  /// Name of the parameter
  final String name;

  /// must be one of: "string","integer","number","boolean","object","array"
  final String type;

  /// if type == "array", this describes each element
  final LLMToolParam? items;

  /// optional JSON-Schema constraints on the array itself
  final int? minItems;
  final int? maxItems;
  final bool? uniqueItems;

  /// A good description of what this parameter entails for the LLM
  final String description;

  /// Whether this parameter is a required input to achieve output
  final bool isRequired;

  /// Possible enum return values (like celsius and fahrenheit)
  final List<String> enums;

  Map<String, dynamic> toJson() {
    // base description
    final json = <String, dynamic>{
      "description": description,
    };

    if (type == "array") {
      json["type"] = "array";
      // must have an items‐schema
      if (items == null) {
        throw StateError("array param '$name' needs an `items` schema");
      }
      // recurse
      json["items"] = items!.toJson();
      if (minItems != null) json["minItems"] = minItems;
      if (maxItems != null) json["maxItems"] = maxItems;
      if (uniqueItems == true) json["uniqueItems"] = true;
    } else {
      // primitive or object
      json["type"] = type;
      if (enums.isNotEmpty) json["enum"] = enums;
      // if you want to support nested objects you could also
      // add a `properties` map here… but that’s another extension.
    }

    return json;
  }
}
