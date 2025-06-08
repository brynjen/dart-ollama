import 'dart:convert';

import '../../domain/model/llm_chunk.dart';
import '../../domain/model/llm_message.dart';
import '../../domain/model/llm_response.dart';
import '../../domain/model/llm_tool_call.dart';

class OllamaResponse extends LLMResponse {
  OllamaResponse({
    required super.model,
    required super.createdAt,
    required super.role,
    required super.content,
    required super.done,
    required super.doneReason,
    required super.promptEvalCount,
    required super.evalCount,
    required super.toolCalls,
  });
}

// {"model":"qwen3:0.6b","created_at":"2025-06-07T20:14:39.400041Z","message":{"role":"assistant","content":"","thinking":"Okay"},"done":false}

// {"model":"qwen3:0.6b","created_at":"2025-06-07T20:22:06.647349Z","message":{"role":"assistant","content":""},"done_reason":"stop","done":true,"total_duration":2621624250,"load_duration":674895833,"prompt_eval_count":18,"prompt_eval_duration":81605000,"eval_count":250,"eval_duration":1864171750}
class OllamaChunk extends LLMChunk {
  OllamaChunk({
    required super.model, 
    required super.createdAt, 
    required super.message,
    super.done,
    super.promptEvalCount,
    super.evalCount,
  });
  
  factory OllamaChunk.fromJson(Map<String, dynamic> json) {
    return OllamaChunk(
      model: json['model'],
      createdAt: DateTime.parse(json['created_at']),
      message: json['message'] != null ? OllamaChunkMessage.fromJson(json['message']) : null,
      done: json['done'],
      promptEvalCount: json['prompt_eval_count'],
      evalCount: json['eval_count'],
    );
  }
}

class OllamaChunkMessage extends LLMChunkMessage {
  OllamaChunkMessage({
    required super.content, 
    required super.role, 
    super.thinking,
    super.toolCalls,
  });
  
  factory OllamaChunkMessage.fromJson(Map<String, dynamic> json) {
    LLMRole? role;
    if (json['role'] != null) {
      try {
        role = LLMRole.values.firstWhere((e) => e.name == json['role']);
      } catch (e) {
        role = null;
      }
    }
    
    // Parse tool calls
    List<LLMToolCall>? toolCalls;
    if (json['tool_calls'] != null) {
      toolCalls = (json['tool_calls'] as List<dynamic>)
          .map((toolCallJson) => LLMToolCall(
                id: null, // Ollama doesn't provide IDs
                name: toolCallJson['function']['name'],
                arguments: jsonEncode(toolCallJson['function']['arguments']),
              ))
          .toList();
    }
    
    // Handle thinking content embedded in content field (when tools are used)
    String? content = json['content'];
    String? thinking = json['thinking'];
    
    if (content != null && content.contains('<think>')) {
      // Extract thinking from content
      final thinkMatch = RegExp(r'<think>(.*?)</think>', dotAll: true).firstMatch(content);
      if (thinkMatch != null) {
        thinking = thinkMatch.group(1)?.trim();
        // Remove thinking tags from content
        content = content.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '').trim();
      }
    }
    
    return OllamaChunkMessage(
      content: content, 
      role: role, 
      thinking: thinking,
      toolCalls: toolCalls,
    );
  }
}
