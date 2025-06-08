class LLMToolCall {
  LLMToolCall({required this.name, required this.arguments, required this.id});

  /// ChatGPT uses id's for toolCalls
  final String? id;
  final String name;
  final String arguments;
}
