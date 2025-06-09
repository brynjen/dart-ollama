import 'llm_tool_param.dart';

abstract class LLMTool {
  /// The name of the tool, used to match up with the function call
  String get name;

  /// Python functions description with description in """ """ as docString
  String get description;

  /// Parameters used for function
  List<LLMToolParam> get parameters;

  /// Description that can be added to the system message to help the LLM understand the tool.
  String get llmDescription => '''- $name: $description''';

  /// Tool used by LLM, can be any type and any number of arguments.
  /// Arguments come in json format. Check tool_parser.dart for more info
  Future<dynamic> execute(Map<String, dynamic> args, {dynamic extra});

  Map<String, dynamic> get toJson {
    final props = {for (final p in parameters) p.name: p.toJsonSchema()};
    final reqs = [
      for (final p in parameters)
        if (p.isRequired) p.name,
    ];

    return {
      "type": "function",
      "function": {
        "name": name,
        "description": description,
        if (parameters.isNotEmpty)
          "parameters": {
            "type": "object",
            "properties": props,
            if (reqs.isNotEmpty) "required": reqs,
          },
      },
    };
  }
}
