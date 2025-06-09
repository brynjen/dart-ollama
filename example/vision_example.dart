import 'dart:convert';
import 'dart:io';

import 'package:dart_ollama/dart_ollama.dart';

Future<void> main() async {
  print('👁️ Dart Ollama Vision Example\n');

  final chatRepository = OllamaChatRepository(
    baseUrl: 'http://localhost:11434',
  );
  final ollamaRepository = OllamaRepository(baseUrl: 'http://localhost:11434');

  // Vision models that support image analysis
  const visionModel = 'gemma3:4b';

  print('🔍 Checking for vision model...');
  await _ensureModelAvailable(ollamaRepository, visionModel);

  // Create a simple test image programmatically
  print('🎨 Downloading test image...');
  final foxImageUrl =
      'https://upload.wikimedia.org/wikipedia/commons/3/30/Vulpes_vulpes_ssp_fulvus.jpg';
  final testImageBase64 = await _downloadAndEncodeImage(foxImageUrl);

  // Example 1: Basic image description
  await _runImageDescriptionExample(
    chatRepository,
    visionModel,
    testImageBase64,
  );

  print('\n${'=' * 50}\n');

  // Example 2: Image analysis with specific questions
  await _runImageAnalysisExample(chatRepository, visionModel, testImageBase64);

  exit(0);
}

Future<void> _runImageDescriptionExample(
  OllamaChatRepository chatRepository,
  String model,
  String imageBase64,
) async {
  print('📸 Example 1: Basic Image Description');

  try {
    final stream = chatRepository.streamChat(
      model,
      messages: [
        LLMMessage(
          role: LLMRole.system,
          content:
              'You are a helpful assistant that describes images accurately and concisely.',
        ),
        LLMMessage(
          role: LLMRole.user,
          content: 'Please describe what you see in this image.',
          images: [imageBase64],
        ),
      ],
    );

    String response = '';
    print('\n🤖 Model response:');

    await for (final chunk in stream) {
      final content = chunk.message?.content ?? '';
      response += content;
      // Print response as it streams (like a typewriter effect)
      stdout.write(content);
      stdout.flush();
    }

    print('\n\n📝 Complete response: $response');
  } catch (e) {
    if (e is VisionNotAllowed) {
      print('❌ Error: The model $model does not support vision capabilities.');
      print('💡 Try using a vision-capable model like llama3.2-vision:11b');
    } else {
      print('❌ Error: $e');
    }
  }
}

Future<void> _runImageAnalysisExample(
  OllamaChatRepository chatRepository,
  String model,
  String imageBase64,
) async {
  print('🔎 Example 2: Detailed Image Analysis');

  try {
    final stream = chatRepository.streamChat(
      model,
      messages: [
        LLMMessage(
          role: LLMRole.system,
          content:
              'You are an expert image analyst. Provide detailed analysis of images including colors, shapes, composition, and any text or objects you can identify.',
        ),
        LLMMessage(
          role: LLMRole.user,
          content:
              'Analyze this image in detail. What colors do you see? What shapes? Any text or patterns? What animals are in the image?',
          images: [imageBase64],
        ),
      ],
    );

    print('\n🔍 Detailed analysis:');

    await for (final chunk in stream) {
      final content = chunk.message?.content ?? '';
      stdout.write(content);
      stdout.flush();
    }

    print('\n\n📋 Analysis complete!');
  } catch (e) {
    if (e is VisionNotAllowed) {
      print('❌ Error: The model $model does not support vision capabilities.');
    } else {
      print('❌ Error: $e');
    }
  }
}

/// Downloads an image from URL and converts it to base64
Future<String> _downloadAndEncodeImage(String imageUrl) async {
  try {
    print('📥 Downloading image from: $imageUrl');

    final httpClient = HttpClient();

    // Set timeouts for the download
    httpClient.connectionTimeout = const Duration(seconds: 30);
    httpClient.idleTimeout = const Duration(seconds: 30);

    final request = await httpClient.getUrl(Uri.parse(imageUrl));
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('Failed to download image: HTTP ${response.statusCode}');
    }

    // Read image bytes
    final imageBytes = <int>[];
    await for (final chunk in response) {
      imageBytes.addAll(chunk);
    }

    httpClient.close();

    // Convert to base64
    final base64Image = base64Encode(imageBytes);

    print('✅ Image downloaded and encoded (${imageBytes.length} bytes)');
    print('🎨 Base64 length: ${base64Image.length} characters');

    return base64Image;
  } catch (e) {
    print('❌ Error downloading image: $e');
    print('💡 Falling back to a simple test pattern...');

    // Fallback to a simple base64 image if download fails
    return _createFallbackImage();
  }
}

/// Creates a simple fallback image as base64 when download fails
String _createFallbackImage() {
  // Simple 1x1 red pixel PNG as fallback
  const fallbackPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==';

  print('🔄 Using fallback test image (1x1 red pixel)');
  return fallbackPng;
}

Future<void> _ensureModelAvailable(
  OllamaRepository repository,
  String modelName,
) async {
  final models = await repository.models();
  if (!models.any((model) => model.name == modelName)) {
    print(
      '📥 Vision model $modelName not found. This is a large model (~6GB).',
    );
    print(
      '⚠️  Pulling large vision models can take significant time and bandwidth.',
    );
    print(
      '🤔 Would you like to continue? This example will pull the model automatically.',
    );
    print('   If you prefer, you can manually run: ollama pull $modelName');

    // For demo purposes, we'll show how to pull but suggest manual installation
    print('\n🚀 Starting model pull...');
    final modelStream = repository.pullModel(modelName);
    await for (final progress in modelStream) {
      stdout.write('\r${progress.status}');
      if (progress.total != null && progress.completed != null) {
        final percentage = (progress.progress * 100).toStringAsFixed(1);
        final bar = _buildProgressBar(progress.progress, 30);
        stdout.write(' $bar $percentage%');
      }
      stdout.flush();
    }
    print('\n✅ Model $modelName pulled successfully.');
  } else {
    print('✅ Vision model $modelName is available.');
  }
}

String _buildProgressBar(double progress, int length) {
  final filledLength = (progress * length).floor();
  final emptyLength = length - filledLength;
  return '[${'=' * filledLength}${' ' * emptyLength}]';
}
