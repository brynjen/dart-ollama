/// llama.cpp backend implementation for LLM interactions.
///
/// This package provides local on-device inference using llama.cpp with GGUF models.
/// Supports Android, iOS, macOS, Windows, and Linux.
///
/// Example usage:
/// ```dart
/// import 'package:llm_llamacpp/llm_llamacpp.dart';
///
/// final repo = LlamaCppChatRepository();
/// await repo.loadModel('/path/to/model.gguf');
///
/// final stream = repo.streamChat('loaded-model', messages: [
///   LLMMessage(role: LLMRole.user, content: 'Hello!')
/// ]);
/// await for (final chunk in stream) {
///   print(chunk.message?.content ?? '');
/// }
///
/// repo.dispose();
/// ```
library;

// Re-export core types for convenience
export 'package:llm_core/llm_core.dart';

// Repository
export 'src/llamacpp_chat_repository.dart';

// Model management
export 'src/llamacpp_model.dart' show LlamaCppModel, ModelLoadOptions;

// Prompt templates
export 'src/prompt_template.dart';
