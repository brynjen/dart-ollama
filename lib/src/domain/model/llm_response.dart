import 'llm_tool_call.dart';

class LLMResponse {
  LLMResponse({
    required this.model,
    required this.createdAt,
    required this.role,
    required this.content,
    required this.done,
    required this.doneReason,
    required this.promptEvalCount,
    required this.evalCount,
    required this.toolCalls,
  });
  final String model;
  final DateTime createdAt;
  final String role;
  final String? content;
  final bool done;
  final String doneReason;
  final int promptEvalCount;
  final int evalCount;
  final List<LLMToolCall>? toolCalls;
}
