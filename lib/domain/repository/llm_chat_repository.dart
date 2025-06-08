import 'package:dart_ollama/domain/model/llm_chunk.dart';
import 'package:dart_ollama/domain/model/llm_embedding.dart';
import 'package:dart_ollama/domain/model/llm_message.dart';
import 'package:dart_ollama/domain/model/llm_tool.dart';

abstract class LLMChatRepository {
  /// The tools available to the repository
  List<LLMTool> availableTools();

  /// Streams a chat from the LLM, returning a stream of [LLMChunk]s. [think] will not yield thinking unless model supports it.
  Stream<LLMChunk> streamChat(
    String model, {
    required List<LLMMessage> messages,
    bool think = false,
    dynamic extra,
  });

   /// Generates embeddings for all [messages] using the [model]. Ensure model supports embeddings.
   Future<List<LLMEmbedding>> embed({
    required String model,
    required List<String> messages,
    Map<String, dynamic> options = const {},
  });
}
