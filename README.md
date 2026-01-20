[![CI](https://github.com/brynjen/dart-ollama/actions/workflows/ci.yaml/badge.svg)](https://github.com/brynjen/dart-ollama/actions/workflows/ci.yaml)
[![pub package](https://img.shields.io/pub/v/dart_ollama.svg)](https://pub.dev/packages/dart_ollama)

# dart_ollama

> ⚠️ **This package is deprecated and no longer maintained.**  
> Please use **[dart-llm](https://pub.dev/packages/llm_ollama)** instead: https://github.com/brynjen/dart-llm

---

A Dart package for interacting with Ollama and ChatGPT APIs. This package provides a simple wrapper for both Ollama and ChatGPT APIs with support for streaming chat responses, tool/function calling, image support, and more.

## Features

* 🚀 **Streaming chat responses** - Real-time streaming of chat responses
* 🔧 **Tool/function calling** - Support for function calling and tool use
* 🖼️ **Image support** - Send images in chat messages
* 🤖 **Multiple backends** - Works with both Ollama and ChatGPT
* 💭 **Thinking support** - Support for Ollama's thinking feature
* 📦 **Easy to use** - Simple and intuitive API

## Migration to dart-llm

This package has been replaced by **[dart-llm](https://pub.dev/packages/dart_llm)**. Please migrate to the new package:

1. Update your `pubspec.yaml`:
   ```yaml
   dependencies:
     dart_llm: ^latest_version  # Replace dart_ollama with dart_llm
   ```

2. Update your imports:
   ```dart
   // Old
   import 'package:dart_ollama/dart_ollama.dart';
   
   // New
   import 'package:dart_llm/dart_llm.dart';
   ```

3. The API is largely compatible, but please refer to the [dart-llm documentation](https://github.com/brynjen/dart-llm) for any changes.

## Installation

> ⚠️ **Note:** This package is deprecated. Please use [dart-llm](https://pub.dev/packages/dart_llm) instead.

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  dart_ollama: ^0.1.6
```

Then run:

```bash
dart pub get
```

## Getting started

### For Ollama

You need to have Ollama running somewhere and have the URL to it. Go to [https://ollama.com/](https://ollama.com/) for installation details. Ollama has easy installation for all operating systems.

You'll also need to download models. For a small and easy model, use `qwen3:0.6b` as an example, it supports both thinking and tools.

### For ChatGPT

If you want to use ChatGPT, add an API key to the `ChatGPTChatRepository`. Remember to not push your API key to GitHub - use an `.env` file and put it there.

## Usage

### Basic Chat Example

```dart
import 'package:dart_ollama/dart_ollama.dart';

Future<void> main() async {
  final chatRepository = OllamaChatRepository(baseUrl: 'http://localhost:11434');
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
}
```

### Using with ChatGPT

```dart
import 'package:dart_ollama/dart_ollama.dart';

Future<void> main() async {
  final chatRepository = ChatGPTChatRepository(apiKey: 'your-api-key');
  final stream = chatRepository.streamChat('gpt-4o',
    messages: [
      LLMMessage(role: LLMRole.user, content: 'Hello, ChatGPT!'),
    ],
  );
  
  String content = '';
  await for (final chunk in stream) {
    content += chunk.message?.content ?? '';
  }
  print(content);
}
```

### Tool/Function Calling

For examples on how to add tools for function calling, check `test/ollama_chat_test.dart` in the repository.

## Additional Information

If you need functionality for Ollama other than chat, the `OllamaRepository` grants you access to common methods like `listModels`, `pullModel`, and `version` for general functionality.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.