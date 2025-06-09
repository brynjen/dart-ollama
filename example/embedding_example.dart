import 'dart:math';

import 'package:dart_ollama/dart_ollama.dart';

Future<void> main() async {
  print('🧮 Dart Ollama Embedding Example\n');

  final chatRepository = OllamaChatRepository(
    baseUrl: 'http://localhost:11434',
  );
  final ollamaRepository = OllamaRepository(baseUrl: 'http://localhost:11434');

  const embeddingModel = 'nomic-embed-text';

  // Ensure the embedding model is available
  await _ensureModelAvailable(ollamaRepository, embeddingModel);

  print('📊 Generating embeddings...\n');

  // Example texts to embed
  final texts = [
    'The quick brown fox jumps over the lazy dog.',
    'A fox is a small carnivorous mammal.',
    'Dogs are loyal companions to humans.',
    'Machine learning is a subset of artificial intelligence.',
    'Neural networks are inspired by biological neural networks.',
    'The weather is sunny and warm today.',
  ];

  // Generate embeddings for all texts
  final embeddings = await chatRepository.embed(
    model: embeddingModel,
    messages: texts,
  );

  print('✅ Generated ${embeddings.length} embeddings');
  print('📏 Embedding dimension: ${embeddings.first.embedding.length}\n');

  // Calculate similarities between texts
  print('🔍 Text Similarity Analysis:\n');

  for (int i = 0; i < texts.length; i++) {
    print('${i + 1}. "${texts[i]}"');

    // Find most similar text
    double maxSimilarity = -1;
    int mostSimilarIndex = -1;

    for (int j = 0; j < texts.length; j++) {
      if (i != j) {
        final similarity = _cosineSimilarity(
          embeddings[i].embedding,
          embeddings[j].embedding,
        );

        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
          mostSimilarIndex = j;
        }
      }
    }

    if (mostSimilarIndex != -1) {
      print('   📊 Most similar to: "${texts[mostSimilarIndex]}"');
      print('   🎯 Similarity score: ${maxSimilarity.toStringAsFixed(4)}');
    }
    print('');
  }

  // Demonstrate semantic search
  print('🔎 Semantic Search Example:\n');

  final query = 'animals and pets';
  print('Query: "$query"');

  final queryEmbedding = await chatRepository.embed(
    model: embeddingModel,
    messages: [query],
  );

  // Find most relevant texts
  final similarities = <MapEntry<int, double>>[];
  for (int i = 0; i < texts.length; i++) {
    final similarity = _cosineSimilarity(
      queryEmbedding.first.embedding,
      embeddings[i].embedding,
    );
    similarities.add(MapEntry(i, similarity));
  }

  // Sort by similarity (highest first)
  similarities.sort((a, b) => b.value.compareTo(a.value));

  print('\n📋 Search Results (ranked by relevance):');
  for (int i = 0; i < min(3, similarities.length); i++) {
    final entry = similarities[i];
    print('${i + 1}. "${texts[entry.key]}"');
    print('   Score: ${entry.value.toStringAsFixed(4)}');
  }
}

/// Calculate cosine similarity between two embedding vectors
double _cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length) {
    throw ArgumentError('Vectors must have the same length');
  }

  double dotProduct = 0.0;
  double normA = 0.0;
  double normB = 0.0;

  for (int i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }

  normA = sqrt(normA);
  normB = sqrt(normB);

  if (normA == 0.0 || normB == 0.0) {
    return 0.0;
  }

  return dotProduct / (normA * normB);
}

Future<void> _ensureModelAvailable(
  OllamaRepository repository,
  String modelName,
) async {
  final models = await repository.models();
  if (!models.any((model) => model.name == modelName)) {
    print('📥 Model $modelName not found. Pulling...');
    final modelStream = repository.pullModel(modelName);
    await for (final progress in modelStream) {
      final statusLine = progress.status;
      if (progress.total != null && progress.completed != null) {
        final percentage = (progress.progress * 100).toStringAsFixed(1);
        final bar = _buildProgressBar(progress.progress, 30);
        print('$statusLine $bar $percentage%');
      } else {
        print(statusLine);
      }
    }
    print('\n✅ Model $modelName pulled successfully.');
  } else {
    print('✅ Model $modelName is available.');
  }
}

String _buildProgressBar(double progress, int length) {
  final filledLength = (progress * length).floor();
  final emptyLength = length - filledLength;
  return '[${'=' * filledLength}${' ' * emptyLength}]';
}
