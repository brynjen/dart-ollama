import '../model/llm_chunk.dart';
import '../model/llm_embedding.dart';
import '../model/llm_message.dart';
import '../model/llm_tool.dart';

abstract class LLMChatRepository {
  /// Streams a chat from the LLM, returning a stream of [LLMChunk]s. [think] will not yield thinking unless model supports it.
  Stream<LLMChunk> streamChat(
    String model, {
    required List<LLMMessage> messages,
    bool think = false,
    /// The tools this message should use.
    List<LLMTool> tools = const [],
    dynamic extra,
  });

  /// Generates embeddings for all [messages] using the [model]. Ensure model supports embeddings.
  Future<List<LLMEmbedding>> embed({
    required String model,
    required List<String> messages,
    Map<String, dynamic> options = const {},
  });
}
