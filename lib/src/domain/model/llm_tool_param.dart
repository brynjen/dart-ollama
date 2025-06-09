class LLMToolParam {
  LLMToolParam({
    required this.name,
    required this.type,
    required this.description,
    this.isRequired = false,
    this.enums = const [],
    this.items, // for arrays
    this.properties, // for objects
    this.additionalProperties, // for objects
    this.minItems, // for arrays
    this.maxItems, // for arrays
    this.uniqueItems, // for arrays
  });

  final String name;

  /// must be one of: "string","integer","number","boolean","object","array"
  final String type;
  final String description;
  final bool isRequired;
  final List<String> enums;

  /// if type=="array", this describes each element
  final LLMToolParam? items;

  /// if type=="object", these are its child properties
  final List<LLMToolParam>? properties;

  /// if type=="object", whether to allow extra fields
  final bool? additionalProperties;

  /// JSON‐Schema keywords on arrays
  final int? minItems;
  final int? maxItems;
  final bool? uniqueItems;

  Map<String, dynamic> toJsonSchema() {
    final schema = <String, dynamic>{"description": description};

    switch (type) {
      case "array":
        schema["type"] = "array";
        if (items == null) {
          throw StateError("Array param '$name' needs an `items` schema");
        }
        schema["items"] = items!.toJsonSchema();
        if (minItems != null) schema["minItems"] = minItems;
        if (maxItems != null) schema["maxItems"] = maxItems;
        if (uniqueItems == true) schema["uniqueItems"] = true;
        break;

      case "object":
        schema["type"] = "object";
        if (properties != null && properties!.isNotEmpty) {
          schema["properties"] = {
            for (var p in properties!) p.name: p.toJsonSchema(),
          };
          final req = [
            for (var p in properties!)
              if (p.isRequired) p.name,
          ];
          if (req.isNotEmpty) schema["required"] = req;
        }
        // default in JSON Schema is true; only write if you want to forbid extras
        if (additionalProperties != null) {
          schema["additionalProperties"] = additionalProperties;
        }
        break;

      default:
        schema["type"] = type;
        if (enums.isNotEmpty) {
          schema["enum"] = enums;
        }
    }

    return schema;
  }
}
