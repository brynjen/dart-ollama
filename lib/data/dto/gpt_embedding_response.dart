import 'package:dart_ollama/domain/model/llm_embedding.dart';

class ChatGPTEmbeddingsResponse {
  ChatGPTEmbeddingsResponse({required this.model, required this.data, required this.usage});
  final String model;
  final String object = 'list';
  final ChatGPTEmbeddingsUsage usage;
  final List<ChatGPTEmbedding> data;

  factory ChatGPTEmbeddingsResponse.fromJson(Map<String, dynamic> json) => ChatGPTEmbeddingsResponse(
        model: json['model'],
        usage: ChatGPTEmbeddingsUsage.fromJson(json['usage']),
        data: (json['data'] as List<dynamic>).map((embeddingJson) => ChatGPTEmbedding.fromJson(embeddingJson)).toList(growable: false),
      );
  Map<String, dynamic> toJson() => {
        'model': model,
        'object': object,
        'usage': usage.toJson(),
        'data': data.map((dataJson) => dataJson.toJson()).toList(growable: false),
      };
}

class ChatGPTEmbedding {
  ChatGPTEmbedding(
      {required this.index, required this.embedding});
  final String object = 'embedding';
  final int index;
  final List<double> embedding;
  factory ChatGPTEmbedding.fromJson(Map<String, dynamic> json) => ChatGPTEmbedding(
        index: json['index'],
        embedding: (json['embedding'] as List<dynamic>).map((e) => e as double).toList(growable: false),
      );
  Map<String, dynamic> toJson() => {
        'index': index,
        'object': object,
        'embedding': embedding,
      };
}

class ChatGPTEmbeddingsUsage {
  ChatGPTEmbeddingsUsage({required this.promptTokens, required this.totalTokens});
  final int promptTokens;
  final int totalTokens;
  factory ChatGPTEmbeddingsUsage.fromJson(Map<String, dynamic> json) =>
      ChatGPTEmbeddingsUsage(promptTokens: json['prompt_tokens'], totalTokens: json['total_tokens']);
  Map<String, dynamic> toJson() => {
        'prompt_tokens': promptTokens,
        'total_tokens': totalTokens,
      };
}

extension ChatGPTLLMEmbedding on ChatGPTEmbeddingsResponse {
  List<LLMEmbedding> get toLLMEmbedding => data
      .map((embedding) =>
          LLMEmbedding(model: model, embedding: embedding.embedding, promptEvalCount: usage.promptTokens))
      .toList(growable: false);
}
/*
{
  "object": "list",
  "data": [
    {
      "object": "embedding",
      "index": 0,
      "embedding": [
        -0.006929283495992422,
        -0.005336422007530928,
        -4.547132266452536e-05,
        -0.024047505110502243
      ],
    }
  ],
  "model": "text-embedding-3-small",
  "usage": {
    "prompt_tokens": 5,
    "total_tokens": 5
  }
}
*/