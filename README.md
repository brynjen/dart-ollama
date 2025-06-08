[![CI](https://github.com/brynjen/dart-ollama/actions/workflows/ci.yaml/badge.svg)](https://github.com/brynjen/dart-ollama/actions/workflows/ci.yaml)

Handlng LLM chat streaming towards Ollama or ChatGPT, letting you easier create
chat bots in dart.

## Features

* Wraps newest Ollama (with thinking) and lets you stream messages
* Supports tool use for function calling
* Support for ChatGPT as well
* For example on how to add a tool, check test/ollama_chat_test.dart

## Getting started
For use with Ollama you need to have it running somewhere and have the url to it.
Go to https://ollama.com/ for details, it has an easy install for all operating systems.
It also requires models to download. For a small and easy model, use qwen3:0.6b as an example.
If you want to use it for ChatGPT, add an apiKey to the ChatGPTRepository and it will use
that instead. Remember to not push your api key to github, add an .env file and put it there

## Usage

```dart
import 'package:dart_ollama/data/repository/ollama_chat_repository.dart';
import 'package:dart_ollama/domain/model/llm_message.dart';

Future<void> main() async {
  final chatRepository = OllamaChatRepository(baseUrl: 'http://localhost:11434');
  final stream = chatRepository.streamChat('qwen3:0.6b',
    messages: [
      LLMMessage(role: LLMRole.system, content: 'Answer short and consise'),
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
}
```

## Additional information
If you need to have functionality for Ollama other than chat, the OllamaRepository grants you access to common methods
like listModels, pullModel and version for some general functionality.