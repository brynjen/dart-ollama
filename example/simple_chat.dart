import 'dart:io';

import 'package:dart_ollama/dart_ollama.dart';

Future<void> main() async {
  final chatRepository = OllamaChatRepository(baseUrl: 'http://localhost:11434');
  final ollamaRepository = OllamaRepository(baseUrl: 'http://localhost:11434');
  final models = await ollamaRepository.models();
  if (!models.any((ollamaModel) => ollamaModel.name == 'qwen3:0.6b')) {
    print('Model qwen3:0.6b not found. Pulling...');
    final modelStream = ollamaRepository.pullModel('qwen3:0.6b');
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
    print('\nModel qwen3:0.6b pulled. Only happens while it is missing.');
  }
  final stream = chatRepository.streamChat('qwen3:0.6b',
    messages: [
      LLMMessage(role: LLMRole.system, content: 'Answer short and concise'),
      LLMMessage(role: LLMRole.user, content: 'Why is the sky blue?'),
    ],
    think: true,
  );
  String thinkingContent = '';
  String content = '';
  await for (final chunk in stream) {
    thinkingContent += chunk.message?.thinking ?? '';
    content += chunk.message?.content ?? '';
  }
  print('Thinking content: $thinkingContent');
  print('Output content: $content');
  exit(0);
}

String _buildProgressBar(double progress, int length) {
  final filledLength = (progress * length).floor();
  final emptyLength = length - filledLength;
  final bar = '[${'=' * filledLength}${' ' * emptyLength}]';
  return bar;
}