# llm_llamacpp

Local LLM inference via llama.cpp for Dart and Flutter.

## Features

- Local on-device inference with GGUF models
- Streaming token generation
- Multiple prompt templates (ChatML, Llama2, Llama3, Alpaca, Vicuna, Phi-3)
- Tool calling via prompt convention
- GPU acceleration support
- Cross-platform: Android, iOS, macOS, Windows, Linux
- Isolate-based inference (non-blocking UI)

## Installation

```yaml
dependencies:
  llm_llamacpp:
    git:
      url: https://github.com/brynjen/dart-ollama.git
      path: packages/llm_llamacpp
```

## Prerequisites

### 1. GGUF Model

Download a model in GGUF format from [Hugging Face](https://huggingface.co/models?search=gguf).

Recommended models:
- `qwen2-0.5b-instruct-q4_k_m.gguf` (~400MB) - Small and fast
- `llama-3.2-1b-instruct-q4_k_m.gguf` (~800MB) - Good balance
- `phi-3-mini-4k-instruct-q4_k_m.gguf` (~2GB) - Higher quality

### 2. Native Library

The llama.cpp shared library must be available:

**Option A**: Build from CI
- Run the GitHub Actions workflow `.github/workflows/build-llamacpp.yaml`
- Download artifacts and place in appropriate locations

**Option B**: Build manually
```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
mkdir build && cd build
cmake .. -DBUILD_SHARED_LIBS=ON
cmake --build . --config Release
```

## Usage

### Basic Chat

```dart
import 'package:llm_llamacpp/llm_llamacpp.dart';

final repo = LlamaCppChatRepository(
  contextSize: 2048,
  nGpuLayers: 0, // Set > 0 for GPU acceleration
);

try {
  await repo.loadModel('/path/to/model.gguf');

  final stream = repo.streamChat('model', messages: [
    LLMMessage(role: LLMRole.system, content: 'You are helpful.'),
    LLMMessage(role: LLMRole.user, content: 'Hello!'),
  ]);

  await for (final chunk in stream) {
    print(chunk.message?.content ?? '');
  }
} finally {
  repo.dispose();
}
```

### Custom Prompt Template

```dart
// Auto-detect from model name
repo.template = getTemplateForModel('llama-3-8b');

// Or set explicitly
repo.template = ChatMLTemplate();
repo.template = Llama3Template();
repo.template = Phi3Template();
```

### GPU Acceleration

```dart
final repo = LlamaCppChatRepository(
  nGpuLayers: 35, // Layers to offload to GPU
);

await repo.loadModel('/path/to/model.gguf', options: ModelLoadOptions(
  nGpuLayers: 35,
  useMemoryMap: true,
));
```

### Tool Calling

Tool calling is implemented via prompt convention (the model outputs JSON):

```dart
final stream = repo.streamChat('model',
  messages: [
    LLMMessage(
      role: LLMRole.system,
      content: '''You have access to tools. To use a tool, output JSON:
{"name": "tool_name", "arguments": {...}}''',
    ),
    ...
  ],
  tools: [MyTool()],
);
```

## Platform Support

| Platform | Architecture | GPU Support |
|----------|--------------|-------------|
| Linux    | x86_64       | CUDA, Vulkan |
| macOS    | arm64, x86_64 | Metal |
| Windows  | x86_64       | CUDA, Vulkan |
| Android  | arm64-v8a    | OpenCL (Adreno) |
| Android  | x86_64       | - |
| iOS      | arm64        | Metal |

## Configuration

```dart
LlamaCppChatRepository(
  contextSize: 4096,    // Token context window
  batchSize: 512,       // Batch size for processing
  threads: null,        // null = auto-detect
  nGpuLayers: 0,        // Layers to offload to GPU
  maxToolAttempts: 25,  // Max tool calling iterations
);
```

## Troubleshooting

### Library not found

Ensure the native library is accessible:
- Current directory
- System library path (`/usr/local/lib`, etc.)
- Next to your executable

### Out of memory

- Use a smaller model (Q4_K_M or Q4_0 quantization)
- Reduce context size
- Offload layers to GPU with `nGpuLayers`

### Slow inference

- Enable GPU acceleration
- Use a more aggressively quantized model
- Reduce context size
- Increase batch size

