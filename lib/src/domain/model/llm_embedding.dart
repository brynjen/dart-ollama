class LLMEmbedding {
  LLMEmbedding({
    required this.model,
    required this.embedding,
    required this.promptEvalCount,
  });
  final String model;
  final List<double> embedding;
  final int promptEvalCount;

  factory LLMEmbedding.fromJson(Map<String, dynamic> json) => LLMEmbedding(
        model: json['model'],
        embedding: json['embeddings'] as List<double>,
        promptEvalCount: json['prompt_eval_count'],
      );
}
