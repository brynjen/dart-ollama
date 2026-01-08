/// llama.cpp backend implementation for LLM interactions.
///
/// This package provides local on-device inference using llama.cpp with GGUF models.
/// Supports Android, iOS, macOS, Windows, and Linux.
///
/// Example usage:
/// ```dart
/// import 'package:llm_llamacpp/llm_llamacpp.dart';
///
/// // Model management
/// final modelRepo = LlamaCppRepository();
/// final models = await modelRepo.discoverModels('/path/to/models');
/// print('Found ${models.length} models');
///
/// // Chat inference
/// final chatRepo = LlamaCppChatRepository();
/// await chatRepo.loadModel('/path/to/model.gguf');
///
/// final stream = chatRepo.streamChat('loaded-model', messages: [
///   LLMMessage(role: LLMRole.user, content: 'Hello!')
/// ]);
/// await for (final chunk in stream) {
///   print(chunk.message?.content ?? '');
/// }
///
/// chatRepo.dispose();
/// modelRepo.dispose();
/// ```
library;

// Re-export core types for convenience
export 'package:llm_core/llm_core.dart';

// Repositories
export 'src/llamacpp_chat_repository.dart';
export 'src/llamacpp_repository.dart';

// Model management
export 'src/llamacpp_model.dart' show LlamaCppModel, ModelLoadOptions;

// GGUF metadata
export 'src/gguf_metadata.dart';

// Model conversion
export 'src/model_converter.dart';

// Prompt templates
export 'src/prompt_template.dart';
