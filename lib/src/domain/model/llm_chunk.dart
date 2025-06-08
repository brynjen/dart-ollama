import 'llm_message.dart';
import 'llm_tool_call.dart';

class LLMChunk {
  LLMChunk({
    required this.model,
    required this.createdAt,
    required this.message,
    this.done,
    this.promptEvalCount,
    this.evalCount,
    this.status,
  });
  final String? model;
  final bool? done;
  final DateTime? createdAt;
  final LLMChunkMessage? message;
  final int? promptEvalCount;
  final int? evalCount;

  /// Status is used in application to inform user about what is happening
  final String? status;
}

class LLMChunkMessage {
  LLMChunkMessage({
    required this.content,
    this.thinking,
    required this.role,
    this.toolCallId,
    this.toolCalls,
    this.images,
  });
  final String? content;
  final String? thinking;
  final LLMRole? role;

  /// ID for tool calls (if applicable).
  final String? toolCallId;

  /// Base64 images or URLs.
  final List<String>? images;

  /// List of tool call data.
  final List<LLMToolCall>? toolCalls;
}
