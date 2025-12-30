import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:llm_core/llm_core.dart';

import 'bindings/llama_bindings.dart';
import 'llamacpp_model.dart';
import 'loader/loader.dart';
import 'prompt_template.dart';

/// Repository for chatting with llama.cpp models locally.
///
/// This repository runs inference in a dedicated isolate to keep the
/// main thread responsive.
///
/// Example:
/// ```dart
/// final repo = LlamaCppChatRepository();
/// await repo.loadModel('/path/to/model.gguf');
///
/// final stream = repo.streamChat('model', messages: [
///   LLMMessage(role: LLMRole.user, content: 'Hello!')
/// ]);
/// await for (final chunk in stream) {
///   print(chunk.message?.content ?? '');
/// }
/// ```
class LlamaCppChatRepository extends LLMChatRepository {
  LlamaCppChatRepository({
    this.contextSize = 4096,
    this.batchSize = 512,
    this.threads,
    this.nGpuLayers = 0,
    this.maxToolAttempts = 25,
    PromptTemplate? template,
  }) : _template = template;

  /// The context size (number of tokens).
  final int contextSize;

  /// The batch size for processing.
  final int batchSize;

  /// Number of threads to use (null = auto-detect).
  final int? threads;

  /// Number of layers to offload to GPU.
  final int nGpuLayers;

  /// Maximum number of tool calling attempts.
  final int maxToolAttempts;

  PromptTemplate? _template;
  LlamaBindings? _bindings;
  LlamaCppModel? _model;
  bool _backendInitialized = false;

  /// The currently loaded model, if any.
  LlamaCppModel? get model => _model;

  /// Whether a model is currently loaded.
  bool get isModelLoaded => _model != null;

  /// Gets the prompt template in use.
  PromptTemplate get template =>
      _template ?? (_model != null ? getTemplateForModel(_model!.path) : ChatMLTemplate());

  /// Sets the prompt template to use.
  set template(PromptTemplate value) => _template = value;

  /// Initializes the llama.cpp backend.
  ///
  /// This is called automatically when loading a model, but can be called
  /// explicitly to pre-initialize.
  void initializeBackend() {
    if (_backendInitialized) return;

    final lib = loadLlamaLibrary();
    _bindings = LlamaBindings(lib);
    _bindings!.llama_backend_init();
    _backendInitialized = true;
  }

  /// Loads a GGUF model from the specified path.
  ///
  /// [modelPath] - Path to the GGUF model file.
  /// [options] - Optional loading options.
  Future<void> loadModel(
    String modelPath, {
    ModelLoadOptions options = const ModelLoadOptions(),
  }) async {
    initializeBackend();

    // Unload any existing model
    if (_model != null) {
      _model!.dispose();
      _model = null;
    }

    _model = LlamaCppModel.load(
      modelPath,
      _bindings!,
      nGpuLayers: options.nGpuLayers,
      useMemoryMap: options.useMemoryMap,
      useMemoryLock: options.useMemoryLock,
      vocabOnly: options.vocabOnly,
    );
  }

  /// Unloads the current model.
  void unloadModel() {
    if (_model != null) {
      _model!.dispose();
      _model = null;
    }
  }

  @override
  Stream<LLMChunk> streamChat(
    String model, {
    required List<LLMMessage> messages,
    List<LLMTool> tools = const [],
    dynamic extra,
    int? toolAttempts,
    bool think = false,
  }) async* {
    if (_model == null) {
      throw ModelLoadException('No model loaded. Call loadModel() first.');
    }

    // Format messages using the template
    final prompt = template.format(messages);

    // Create a receive port to get tokens from the isolate
    final receivePort = ReceivePort();

    // Start inference in an isolate
    final isolate = await Isolate.spawn(
      _runInference,
      _InferenceRequest(
        sendPort: receivePort.sendPort,
        modelPath: _model!.path,
        prompt: prompt,
        stopTokens: template.stopTokens,
        contextSize: contextSize,
        batchSize: batchSize,
        threads: threads,
        nGpuLayers: nGpuLayers,
        temperature: 0.7,
        topP: 0.9,
        topK: 40,
        maxTokens: 2048,
      ),
    );

    try {
      String accumulatedContent = '';
      List<LLMToolCall> collectedToolCalls = [];

      await for (final message in receivePort) {
        if (message is _InferenceToken) {
          accumulatedContent += message.token;

          yield LLMChunk(
            model: model,
            createdAt: DateTime.now(),
            message: LLMChunkMessage(
              content: message.token,
              role: LLMRole.assistant,
            ),
            done: false,
          );
        } else if (message is _InferenceComplete) {
          // Check for tool calls in the response
          if (tools.isNotEmpty) {
            final parsedToolCalls = _parseToolCalls(accumulatedContent);
            if (parsedToolCalls.isNotEmpty) {
              collectedToolCalls.addAll(parsedToolCalls);
            }
          }

          yield LLMChunk(
            model: model,
            createdAt: DateTime.now(),
            message: LLMChunkMessage(
              content: null,
              role: LLMRole.assistant,
              toolCalls: collectedToolCalls.isEmpty ? null : collectedToolCalls,
            ),
            done: true,
            promptEvalCount: message.promptTokens,
            evalCount: message.generatedTokens,
          );

          // Handle tool calls if any
          if (collectedToolCalls.isNotEmpty && tools.isNotEmpty) {
            final currentAttempts = toolAttempts ?? maxToolAttempts;
            if (currentAttempts > 0) {
              final workingMessages = List<LLMMessage>.from(messages);

              // Add assistant message with tool calls
              workingMessages.add(LLMMessage(
                role: LLMRole.assistant,
                content: accumulatedContent,
              ));

              // Execute tools and add responses
              for (final toolCall in collectedToolCalls) {
                final tool = tools.firstWhere(
                  (t) => t.name == toolCall.name,
                  orElse: () =>
                      throw Exception('Tool ${toolCall.name} not found'),
                );

                final toolResponse = await tool.execute(
                      json.decode(toolCall.arguments),
                      extra: extra,
                    ) ??
                    'Tool ${toolCall.name} returned null';

                workingMessages.add(LLMMessage(
                  role: LLMRole.tool,
                  content: toolResponse.toString(),
                  toolCallId: toolCall.id,
                ));
              }

              // Continue conversation with tool results
              yield* streamChat(
                model,
                messages: workingMessages,
                tools: tools,
                extra: extra,
                toolAttempts: currentAttempts - 1,
              );
            }
          }

          break;
        } else if (message is _InferenceError) {
          throw Exception('Inference error: ${message.error}');
        }
      }
    } finally {
      receivePort.close();
      isolate.kill();
    }
  }

  /// Parses tool calls from model output.
  ///
  /// This looks for JSON-formatted tool calls in the response.
  List<LLMToolCall> _parseToolCalls(String content) {
    final toolCalls = <LLMToolCall>[];

    // Look for JSON tool call patterns
    // Common formats:
    // 1. {"name": "tool_name", "arguments": {...}}
    // 2. <tool_call>{"name": "tool_name", "arguments": {...}}</tool_call>
    // 3. Action: tool_name\nAction Input: {...}

    // Try JSON format
    final jsonPattern = RegExp(
      r'\{[^{}]*"name"\s*:\s*"([^"]+)"[^{}]*"arguments"\s*:\s*(\{[^{}]*\})[^{}]*\}',
      multiLine: true,
    );

    for (final match in jsonPattern.allMatches(content)) {
      try {
        final name = match.group(1)!;
        final args = match.group(2)!;

        toolCalls.add(LLMToolCall(
          id: 'call_${toolCalls.length}',
          name: name,
          arguments: args,
        ));
      } catch (_) {
        // Skip invalid matches
      }
    }

    // Try XML-like format
    final xmlPattern = RegExp(
      r'<tool_call>\s*(\{.*?\})\s*</tool_call>',
      multiLine: true,
      dotAll: true,
    );

    for (final match in xmlPattern.allMatches(content)) {
      try {
        final jsonStr = match.group(1)!;
        final data = json.decode(jsonStr) as Map<String, dynamic>;

        toolCalls.add(LLMToolCall(
          id: 'call_${toolCalls.length}',
          name: data['name'] as String,
          arguments: json.encode(data['arguments']),
        ));
      } catch (_) {
        // Skip invalid matches
      }
    }

    return toolCalls;
  }

  @override
  Future<List<LLMEmbedding>> embed({
    required String model,
    required List<String> messages,
    Map<String, dynamic> options = const {},
  }) async {
    // Embeddings require a different approach with llama.cpp
    // For now, throw unsupported
    throw UnsupportedError(
      'Embeddings are not yet implemented for llama.cpp backend. '
      'Use a dedicated embedding model or the Ollama/ChatGPT backends.',
    );
  }

  /// Releases all resources.
  void dispose() {
    unloadModel();
    if (_backendInitialized && _bindings != null) {
      _bindings!.llama_backend_free();
      _backendInitialized = false;
    }
  }
}

// Isolate communication messages

class _InferenceRequest {
  _InferenceRequest({
    required this.sendPort,
    required this.modelPath,
    required this.prompt,
    required this.stopTokens,
    required this.contextSize,
    required this.batchSize,
    this.threads,
    required this.nGpuLayers,
    required this.temperature,
    required this.topP,
    required this.topK,
    required this.maxTokens,
  });

  final SendPort sendPort;
  final String modelPath;
  final String prompt;
  final List<String> stopTokens;
  final int contextSize;
  final int batchSize;
  final int? threads;
  final int nGpuLayers;
  final double temperature;
  final double topP;
  final int topK;
  final int maxTokens;
}

class _InferenceToken {
  _InferenceToken(this.token);
  final String token;
}

class _InferenceComplete {
  _InferenceComplete({
    required this.promptTokens,
    required this.generatedTokens,
  });
  final int promptTokens;
  final int generatedTokens;
}

class _InferenceError {
  _InferenceError(this.error);
  final String error;
}

/// Runs inference in an isolate.
void _runInference(_InferenceRequest request) {
  try {
    // Initialize llama.cpp in this isolate
    final lib = loadLlamaLibrary();
    final bindings = LlamaBindings(lib);
    bindings.llama_backend_init();

    // Load the model
    final modelParams = bindings.llama_model_default_params();
    modelParams.n_gpu_layers = request.nGpuLayers;

    final modelPathPtr = request.modelPath.toNativeUtf8();
    final model = bindings.llama_load_model_from_file(
      modelPathPtr.cast(),
      modelParams,
    );
    calloc.free(modelPathPtr);

    if (model == nullptr) {
      request.sendPort.send(_InferenceError('Failed to load model'));
      return;
    }

    // Create context
    final ctxParams = bindings.llama_context_default_params();
    ctxParams.n_ctx = request.contextSize;
    ctxParams.n_batch = request.batchSize;
    if (request.threads != null) {
      ctxParams.n_threads = request.threads!;
      ctxParams.n_threads_batch = request.threads!;
    }

    final ctx = bindings.llama_new_context_with_model(model, ctxParams);
    if (ctx == nullptr) {
      bindings.llama_free_model(model);
      request.sendPort.send(_InferenceError('Failed to create context'));
      return;
    }

    try {
      // Tokenize prompt
      final promptPtr = request.prompt.toNativeUtf8();
      final maxTokens = request.prompt.length + 256;
      final tokensPtr = calloc<Int32>(maxTokens);

      final nTokens = bindings.llama_tokenize(
        model,
        promptPtr.cast(),
        request.prompt.length,
        tokensPtr,
        maxTokens,
        true, // add_special
        true, // parse_special
      );
      calloc.free(promptPtr);

      if (nTokens < 0) {
        calloc.free(tokensPtr);
        request.sendPort.send(_InferenceError('Failed to tokenize prompt'));
        return;
      }

      // Evaluate prompt
      var batch = bindings.llama_batch_get_one(tokensPtr, nTokens, 0, 0);
      if (bindings.llama_decode(ctx, batch) != 0) {
        calloc.free(tokensPtr);
        request.sendPort.send(_InferenceError('Failed to evaluate prompt'));
        return;
      }

      // Set up sampling
      final sampler = bindings.llama_sampler_chain_init(nullptr);
      bindings.llama_sampler_chain_add(
        sampler,
        bindings.llama_sampler_init_temp(request.temperature),
      );
      bindings.llama_sampler_chain_add(
        sampler,
        bindings.llama_sampler_init_top_k(request.topK),
      );
      bindings.llama_sampler_chain_add(
        sampler,
        bindings.llama_sampler_init_top_p(request.topP, 1),
      );
      bindings.llama_sampler_chain_add(
        sampler,
        bindings.llama_sampler_init_dist(42), // seed
      );

      // Generate tokens
      final bufferSize = 256;
      final pieceBuffer = calloc<Char>(bufferSize);
      var generatedTokens = 0;
      var currentPos = nTokens;
      final newTokenPtr = calloc<Int32>(1);

      while (generatedTokens < request.maxTokens) {
        // Sample next token
        final newToken = bindings.llama_sampler_sample(sampler, ctx, -1);

        // Check for end of generation
        if (bindings.llama_token_is_eog(model, newToken)) {
          break;
        }

        // Convert token to text
        final pieceLen = bindings.llama_token_to_piece(
          model,
          newToken,
          pieceBuffer,
          bufferSize,
          0, // lstrip
          true, // special
        );

        if (pieceLen > 0) {
          final piece = pieceBuffer.cast<Utf8>().toDartString(length: pieceLen);

          // Check for stop tokens
          bool shouldStop = false;
          for (final stopToken in request.stopTokens) {
            if (piece.contains(stopToken)) {
              shouldStop = true;
              break;
            }
          }

          if (shouldStop) break;

          request.sendPort.send(_InferenceToken(piece));
        }

        // Decode the new token
        newTokenPtr.value = newToken;
        batch = bindings.llama_batch_get_one(newTokenPtr, 1, currentPos, 0);
        if (bindings.llama_decode(ctx, batch) != 0) {
          break;
        }

        currentPos++;
        generatedTokens++;
      }

      // Cleanup sampling
      bindings.llama_sampler_free(sampler);
      calloc.free(pieceBuffer);
      calloc.free(newTokenPtr);
      calloc.free(tokensPtr);

      request.sendPort.send(_InferenceComplete(
        promptTokens: nTokens,
        generatedTokens: generatedTokens,
      ));
    } finally {
      bindings.llama_free(ctx);
      bindings.llama_free_model(model);
      bindings.llama_backend_free();
    }
  } catch (e) {
    request.sendPort.send(_InferenceError(e.toString()));
  }
}

