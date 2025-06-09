import 'dart:io';

import 'package:dart_ollama/dart_ollama.dart';

/// Basic Chat Example
///
/// This example demonstrates:
/// - Setting up a chat repository
/// - Pulling models if they don't exist
/// - Streaming chat responses with thinking
/// - Displaying progress bars for model downloads
Future<void> main() async {
  print('💬 Dart Ollama Basic Chat Example\n');

  // Initialize repositories
  final chatRepository = OllamaChatRepository(
    baseUrl: 'http://localhost:11434',
  );
  final ollamaRepository = OllamaRepository(baseUrl: 'http://localhost:11434');

  const model = 'qwen3:0.6b'; // Small model with thinking and tool support

  // Ensure the model is available
  await _ensureModelAvailable(ollamaRepository, model);

  print('\n🚀 Starting conversation...\n');

  // Example conversation with thinking enabled
  await _runBasicChatExample(chatRepository, model);

  print('\n' + '=' * 50 + '\n');

  // Example without thinking to show the difference
  await _runChatWithoutThinking(chatRepository, model);

  print('\n✅ Examples completed successfully!');
  exit(0);
}

/// Demonstrates chat with thinking enabled
Future<void> _runBasicChatExample(
  OllamaChatRepository chatRepository,
  String model,
) async {
  print('🧠 Example 1: Chat with Thinking Mode');
  print('Question: Why is the sky blue?');

  final stream = chatRepository.streamChat(
    model,
    messages: [
      LLMMessage(
        role: LLMRole.system,
        content:
            'You are a helpful assistant. Answer questions accurately and concisely. '
            'Show your reasoning process when thinking mode is enabled.',
      ),
      LLMMessage(role: LLMRole.user, content: 'Why is the sky blue?'),
    ],
    think: true, // Enable thinking mode to see the model's reasoning
  );

  String thinkingContent = '';
  String responseContent = '';

  print('\n🤖 Streaming response...\n');

  await for (final chunk in stream) {
    // Collect thinking content (reasoning process)
    if (chunk.message?.thinking != null) {
      thinkingContent += chunk.message!.thinking!;
    }

    // Collect and display response content as it streams
    if (chunk.message?.content != null) {
      final content = chunk.message!.content!;
      responseContent += content;
      stdout.write(content); // Show streaming effect
      stdout.flush();
    }
  }

  print('\n\n🤔 Model\'s thinking process:');
  print(
    thinkingContent.isEmpty
        ? '(No thinking output available)'
        : thinkingContent,
  );

  print('\n📝 Complete response:');
  print(responseContent);
}

/// Demonstrates chat without thinking for comparison
Future<void> _runChatWithoutThinking(
  OllamaChatRepository chatRepository,
  String model,
) async {
  print('💭 Example 2: Chat without Thinking Mode');
  print('Question: What is machine learning?');

  final stream = chatRepository.streamChat(
    model,
    messages: [
      LLMMessage(
        role: LLMRole.system,
        content:
            'You are a helpful assistant. Provide clear, concise explanations.',
      ),
      LLMMessage(role: LLMRole.user, content: 'What is machine learning?'),
    ],
    think: false, // Disable thinking mode for faster, direct responses
  );

  String responseContent = '';

  print('\n🤖 Streaming response...\n');

  await for (final chunk in stream) {
    if (chunk.message?.content != null) {
      final content = chunk.message!.content!;
      responseContent += content;
      stdout.write(content);
      stdout.flush();
    }
  }

  print('\n\n📝 Complete response:');
  print(responseContent);
}

/// Ensures the specified model is available, pulling it if necessary
Future<void> _ensureModelAvailable(
  OllamaRepository repository,
  String modelName,
) async {
  try {
    final models = await repository.models();
    if (!models.any((model) => model.name == modelName)) {
      print('📥 Model $modelName not found. Pulling...');
      print('⏳ This may take a few minutes for the first download.');

      final modelStream = repository.pullModel(modelName);
      await for (final progress in modelStream) {
        // Clear the line and show progress
        stdout.write('\r${progress.status}');
        if (progress.total != null && progress.completed != null) {
          final percentage = (progress.progress * 100).toStringAsFixed(1);
          final bar = _buildProgressBar(progress.progress, 30);
          stdout.write(' $bar $percentage%');
        }
        stdout.flush();
      }
      print('\n✅ Model $modelName downloaded successfully!');
    } else {
      print('✅ Model $modelName is already available.');
    }
  } catch (e) {
    print('❌ Error checking/pulling model: $e');
    print(
      '💡 Make sure Ollama is running and accessible at http://localhost:11434',
    );
    exit(1);
  }
}

/// Creates a visual progress bar for model downloads
String _buildProgressBar(double progress, int length) {
  final filledLength = (progress * length).floor();
  final emptyLength = length - filledLength;
  return '[${'=' * filledLength}${' ' * emptyLength}]';
}
