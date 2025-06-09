# dart_ollama Examples

This directory contains examples demonstrating how to use the `dart_ollama` package to interact with Ollama language models.

## Prerequisites

Before running these examples, make sure you have:

1. **Ollama installed and running**: Download from [ollama.com](https://ollama.com)
2. **Required models pulled**: The examples use `qwen3:0.6b` which supports tools and thinking
   ```bash
   ollama pull qwen3:0.6b
   ```

## Examples

### 1. Basic Chat (`main.dart`)

A simple chat example that demonstrates:
- Model pulling if not available
- Basic conversation with system and user messages
- Thinking mode (shows the model's reasoning process)
- Progress bar for model downloading

```bash
dart run example/main.dart
```

### 2. Tool Usage (`tool_example.dart`)

Demonstrates how to use tools (function calling) with Ollama:
- Creating custom tools that the model can call
- Calculator tool for mathematical operations
- Text formatting tool
- Tool chaining and multiple tool usage

```bash
dart run example/tool_example.dart
```

### 3. Vision Example (`vision_example.dart`)

Shows how to use vision-capable models:
- Image analysis and description
- Base64 image encoding
- Vision model capabilities checking

```bash
dart run example/vision_example.dart
```

### 4. Embedding Example (`embedding_example.dart`)

Demonstrates text embedding generation:
- Creating embeddings for text
- Using embedding models
- Similarity calculations

```bash
dart run example/embedding_example.dart
```

## Running Examples

1. Start Ollama server:
   ```bash
   ollama serve
   ```

2. Run any example:
   ```bash
   dart run example/<example_file>.dart
   ```

## Model Requirements

- **Chat models**: `qwen3:0.6b`, `qwen2.5:0.5b`, `llama3.2:1b`
- **Vision models**: `llama3.2-vision:11b`, `gemma3:4b`
- **Embedding models**: `nomic-embed-text`, `mxbai-embed-large`

The examples will automatically pull required models if they're not available locally.

## Features Demonstrated

- ✅ **Streaming chat completions**
- ✅ **Tool/function calling**
- ✅ **Vision and image analysis**
- ✅ **Text embeddings**
- ✅ **Thinking mode** (model reasoning)
- ✅ **Model management** (pulling, checking availability)
- ✅ **Error handling** (model capabilities, network issues)
- ✅ **Progress tracking** (download progress, streaming responses)
