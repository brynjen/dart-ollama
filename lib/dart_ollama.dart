/// A Dart package for interacting with Ollama and ChatGPT APIs.
///
/// This package provides a simple wrapper for Ollama and ChatGPT APIs with support for:
/// * Streaming chat responses
/// * Tool/function calling
/// * Image support
/// * Both Ollama and ChatGPT backends
///
/// Example usage:
/// ```dart
/// import 'package:dart_ollama/dart_ollama.dart';
///
/// final repository = OllamaChatRepository(baseUrl: 'http://localhost:11434');
/// final stream = repository.streamChat('qwen3:0.6b', messages: [
///   LLMMessage(role: LLMRole.user, content: 'Hello!')
/// ]);
/// ```
library;

// Repositories
export 'src/data/repository/ollama_chat_repository.dart'
    show OllamaChatRepository;
export 'src/data/repository/chatgpt_chat_repository.dart'
    show ChatGPTChatRepository;
export 'src/data/repository/ollama_repository.dart' show OllamaRepository;

// Models
export 'src/domain/model/llm_chunk.dart' show LLMChunk;
export 'src/domain/model/llm_message.dart' show LLMMessage, LLMRole;
export 'src/domain/model/llm_tool.dart' show LLMTool;
export 'src/domain/model/llm_tool_call.dart' show LLMToolCall;
export 'src/domain/model/llm_tool_param.dart' show LLMToolParam;

// DTOs
export 'src/data/dto/ollama_model.dart'
    show OllamaModel, OllamaModelInfo, OllamaVersion, OllamaPullProgress;

// Interfaces
export 'src/domain/repository/llm_chat_repository.dart' show LLMChatRepository;

// Exceptions
export 'src/domain/exceptions/ollama_exceptions.dart';
