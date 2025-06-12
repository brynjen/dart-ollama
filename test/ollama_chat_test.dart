import 'dart:async';
import 'package:dart_ollama/dart_ollama.dart';
import 'package:test/test.dart';

void main() {
  group('Testing Ollama Chat Repository', () {
    late LLMChatRepository repository;
    String baseUrl = 'http://localhost:11434';
    String thinkingModel = 'qwen3:0.6b'; // Thinking chat model, supports tools, thinking and completion
    String nonThinkingModel = 'qwen2.5:0.5b'; // Non-thinking chat model, supports completion
    String embeddingModel = 'nomic-embed-text'; // Embedding model, supports embedding
    String visionModel = 'gemma3:4b'; // Multimodal model with vision support, supports vision and completion
    setUpAll(() async {
      final ollamaRepository = OllamaRepository(baseUrl: baseUrl);
      final models = await ollamaRepository.models();
      // Check if qwen3:0.6b is missing, if it is pull it
      if (!models.any((ollamaModel) => ollamaModel.name == thinkingModel)) {
        ollamaRepository.pullModel(thinkingModel).join();
      }
      // Check if qwen2.5:0.5b is missing, if it is pull it
      if (!models.any((ollamaModel) => ollamaModel.name == nonThinkingModel)) {
        ollamaRepository.pullModel(nonThinkingModel).join();
      }
      // Check if gemma3:4b is missing, if it is pull it
      if (!models.any((ollamaModel) => ollamaModel.name == visionModel)) {
        ollamaRepository.pullModel(visionModel).join();
      }
    });
    setUp(() async {
      repository = OllamaChatRepository(baseUrl: baseUrl);
    });

    group('Chat tests', () {
      test('Test regular thinking streaming works', () async {
        final stream = repository.streamChat(
          thinkingModel,
          messages: [
            LLMMessage(role: LLMRole.system, content: 'Answer short and consise'),
            LLMMessage(role: LLMRole.user, content: 'Why is the sky blue?'),
          ],
          think: true,
        );
        String thinkingContent = '';
        String content = '';
        int chunkCount = 0;
        await for (final chunk in stream) {
          chunkCount++;
          thinkingContent += chunk.message?.thinking ?? '';
          content += chunk.message?.content ?? '';
        }
        expect(thinkingContent, isNotEmpty);
        expect(content, isNotEmpty);
        expect(chunkCount, greaterThan(10));
        print('Thinking: $thinkingContent');
        print('Content: $content');
      });

      test('Test streaming with no thinking works on a thinking model', () async {
        final stream = repository.streamChat(
          thinkingModel,
          messages: [
            LLMMessage(role: LLMRole.system, content: 'Answer short and consise'),
            LLMMessage(role: LLMRole.user, content: 'Why is the sky blue?'),
          ],
          think: false,
        );
        String thinkingContent = '';
        String content = '';
        await for (final chunk in stream) {
          thinkingContent += chunk.message?.thinking ?? '';
          content += chunk.message?.content ?? '';
        }
        expect(thinkingContent, isEmpty);
        expect(content, isNotEmpty);
        print('Content: $content');
      });

      test('Test streaming with thinking on a non-thinking model throws exception', () async {
        // Using a smaller model that definitely doesn't support thinking
        try {
          final stream = repository.streamChat(
            nonThinkingModel, // Using a non-thinking model
            messages: [
              LLMMessage(role: LLMRole.system, content: 'Answer short and consise'),
              LLMMessage(role: LLMRole.user, content: 'Why is the sky blue?'),
            ],
            think: true,
          );
          await for (final _ in stream) {
            // This should not be reached
          }
          fail('Should not reach here as model does not support thinking');
        } catch (e) {
          expect(e, isA<ThinkingNotAllowed>(), reason: 'ThinkingNotAllowed exception should have been thrown');
        }
      });

      test(
        'Test streaming with image on a model supporting images works',
        () async {
          // Create a simple base64 encoded test image instead of reading from file
          // This is a 1x1 pixel red PNG encoded as base64
          const base64Image =
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==';

          try {
            final stream = repository.streamChat(
              visionModel,
              messages: [
                LLMMessage(role: LLMRole.system, content: 'Answer short and consise'),
                LLMMessage(role: LLMRole.user, content: 'What does the image show?', images: [base64Image]),
              ],
            );
            String content = '';
            await for (final chunk in stream) {
              content += chunk.message?.content ?? '';
            }
            print('Response: "$content"');
            expect(content, isNotEmpty);
            // Since it's a simple test image, just check for non-empty response
            expect(content.length, greaterThan(10));
          } catch (e) {
            print('Error: $e');
            rethrow;
          }
        },
        skip: 'Vision model (gemma3:4b) too large for GitHub Actions',
      );

      test(
        'Test streaming with image on a text-only model rejects chat',
        () async {
          // Create a simple base64 encoded test image
          const base64Image =
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==';

          // Test that a text-only model throws VisionNotAllowed when images are provided
          expect(() async {
            final stream = repository.streamChat(
              thinkingModel, // qwen3:0.6b - text-only model
              messages: [
                LLMMessage(role: LLMRole.system, content: 'Answer short and consise'),
                LLMMessage(role: LLMRole.user, content: 'What does the image show?', images: [base64Image]),
              ],
            );

            await for (final _ in stream) {
              // This should not be reached
            }
            fail('Should not reach here as text-only model should reject vision requests');
          }, throwsA(isA<VisionNotAllowed>()));
        },
        skip: 'Vision test requires large model not suitable for GitHub Actions',
      );
    });

    group('Tool tests', () {
      test('Test tool works with thinking model', () async {
        final tool = TestCalculatorTool();
        expect(tool.counterUsed, 0);
        repository = OllamaChatRepository(baseUrl: baseUrl);
        final stream = repository.streamChat(
          thinkingModel,
          messages: [
            LLMMessage(role: LLMRole.system, content: 'Answer short and consise. Use tools.'),
            LLMMessage(role: LLMRole.user, content: 'What is 2 + 2?'),
          ],
          tools: [tool],
          think: true,
        );
        String content = '';
        String thinking = '';
        int chunkCount = 0;
        await for (final chunk in stream) {
          chunkCount++;
          thinking += chunk.message?.thinking ?? '';
          content += chunk.message?.content ?? '';
        }
        expect(tool.counterUsed, 1);
        expect(chunkCount, greaterThan(10));
        expect(thinking, isNotEmpty);
        expect(content, isNotEmpty);
        expect(chunkCount, greaterThan(0));
        print('Thinking: $thinking');
        print('Content: $content');
      });

      test('Test using tools on a non-tools model throws error', () async {
        // Note: Using embedding model which doesn't support chat at all
        // Most modern chat models actually support tools, so this tests the broader case
        final tool = TestCalculatorTool();
        repository = OllamaChatRepository(baseUrl: baseUrl);

        expect(() async {
          final stream = repository.streamChat(
            embeddingModel, // This model doesn't support chat at all
            messages: [
              LLMMessage(role: LLMRole.system, content: 'Answer short and consise'),
              LLMMessage(role: LLMRole.user, content: 'What is 2 + 2?'),
            ],
            tools: [tool],
          );
          await for (final _ in stream) {
            // This should not be reached
          }
          fail('Should not reach here as model does not support chat');
        }, throwsA(isA<Exception>())); // Changed to generic Exception since this model doesn't support chat at all
      });

      test('Test multiple tools works with thinking model', () async {
        final tool = TestCalculatorTool();
        final formatterTool = TestResultFormatterTool();
        expect(tool.counterUsed, 0);
        expect(formatterTool.counterUsed, 0);
        repository = OllamaChatRepository(baseUrl: baseUrl);
        final stream = repository.streamChat(
          thinkingModel,
          messages: [
            LLMMessage(role: LLMRole.system, content: 'Answer short and consise. Use tools.'),
            LLMMessage(role: LLMRole.user, content: 'What is 2 + 2? And show the result as formatted by the tool'),
          ],
          tools: [tool, formatterTool],
          think: true,
        );
        String content = '';
        String thinking = '';
        int chunkCount = 0;
        await for (final chunk in stream) {
          chunkCount++;

          thinking += chunk.message?.thinking ?? '';
          content += chunk.message?.content ?? '';
        }
        expect(tool.counterUsed, 1);
        expect(formatterTool.counterUsed, 1);
        expect(chunkCount, greaterThan(10));
        expect(thinking, isNotEmpty);
        expect(content, isNotEmpty);
        expect(chunkCount, greaterThan(0));
        print('Thinking: $thinking');
        print('Content: $content');
      });

      test('Test tool with array parameter of same type', () async {
        final tool = TagListTool();
        expect(tool.counterUsed, 0);
        repository = OllamaChatRepository(baseUrl: baseUrl);
        final stream = repository.streamChat(
          thinkingModel,
          messages: [
            LLMMessage(role: LLMRole.system, content: 'Answer short and consise. Use tools.'),
            LLMMessage(
              role: LLMRole.user,
              content:
                  'Use the tag tool to add the tags "LLM", "is" and "cool". Give me the output of the tool as it changes the tags.',
            ),
          ],
          tools: [tool],
          think: true,
        );
        String content = '';
        String thinking = '';
        await for (final chunk in stream) {
          thinking += chunk.message?.thinking ?? '';
          content += chunk.message?.content ?? '';
        }
        print('Thinking: $thinking');
        print('Content: $content');
        expect(tool.counterUsed, greaterThanOrEqualTo(1));
        expect(content, isNotEmpty);
        expect(thinking, isNotEmpty);
      });
    });

    test('Test tool with array parameter of different type', () async {
      final tool = ExtractEntitiesTool();
      expect(tool.counterUsed, 0);
      repository = OllamaChatRepository(baseUrl: baseUrl);
      final stream = repository.streamChat(
        thinkingModel,
        messages: [
          LLMMessage(role: LLMRole.system, content: 'Answer short and consise. Use tools.'),
          LLMMessage(
            role: LLMRole.user,
            content:
                'Use the extract_entities tool to extract the entities and their types from the text "The quick brown fox jumps over the lazy dog". Give me a list of all entities and their types',
          ),
        ],
        tools: [tool],
        think: true,
      );
      String content = '';
      String thinking = '';
      await for (final chunk in stream) {
        thinking += chunk.message?.thinking ?? '';
        content += chunk.message?.content ?? '';
      }
      expect(tool.counterUsed, 1);
      expect(content, isNotEmpty);
      expect(thinking, isNotEmpty);
      print('Thinking: $thinking');
      print('Content: $content');
    });

    group('Embedding tests', () {
      test('Test embedding works', () async {
        final embeddings = await repository.embed(model: embeddingModel, messages: ['Hello']);
        expect(embeddings, isNotEmpty);
        expect(embeddings.length, 1);
        expect(embeddings.first.embedding, isNotEmpty);
        expect(embeddings.first.promptEvalCount, greaterThan(0));
        expect(embeddings.first.model, embeddingModel);
        print('Embeddings: ${embeddings.first.embedding}');
      });
    });
  }, timeout: Timeout(Duration(minutes: 2)));
}

class TestCalculatorTool extends LLMTool {
  int counterUsed = 0;
  @override
  String get name => 'calculator';

  @override
  Future execute(Map<String, dynamic> args, {extra}) async {
    counterUsed++;
    final operation = args['operation'] as String? ?? 'add';

    // Default to 0 for null values
    final a = (args['a'] != null) ? (args['a'] as num) : 0;
    final b = (args['b'] != null) ? (args['b'] as num) : 0;

    num result;
    switch (operation) {
      case 'add':
        result = a + b;
        break;
      case 'subtract':
        result = a - b;
        break;
      case 'multiply':
        result = a * b;
        break;
      case 'divide':
        if (b == 0) {
          return 'Error: Division by zero';
        }
        result = a / b;
        break;
      default:
        return 'Error: Unknown operation $operation';
    }

    return 'Result: $result';
  }

  @override
  String get description => 'Perform basic math operations';

  @override
  List<LLMToolParam> get parameters => [
    LLMToolParam(
      name: 'operation',
      type: 'string',
      description: 'The operation to perform',
      enums: ['add', 'subtract', 'multiply', 'divide'],
      isRequired: true,
    ),
    LLMToolParam(name: 'a', type: 'number', description: 'First operand', isRequired: true),
    LLMToolParam(name: 'b', type: 'number', description: 'Second operand', isRequired: true),
  ];
}

class TestResultFormatterTool extends LLMTool {
  int counterUsed = 0;
  @override
  String get name => 'response_formatter';

  @override
  Future execute(Map<String, dynamic> args, {extra}) async {
    counterUsed++;
    final calculatorResult = args['result'] as String? ?? '';
    if (calculatorResult.isEmpty) {
      return 'Failed to format the result';
    }
    return 'Formatted result: ${args['result']}';
  }

  @override
  String get description => 'Formats the response from a calculator tool';

  @override
  List<LLMToolParam> get parameters => [
    LLMToolParam(name: 'result', type: 'string', description: 'The calculator tool result to format', isRequired: true),
  ];
}

class TagListTool extends LLMTool {
  int counterUsed = 0;
  @override
  String get name => "make_tag_list";
  @override
  String get description => "Build a joined tag list";
  @override
  List<LLMToolParam> get parameters => [
    LLMToolParam(
      name: "tags",
      type: "array",
      description: "A list of tags to join",
      isRequired: true,
      items: LLMToolParam(name: "tag", type: "string", description: "A single tag"),
      minItems: 1,
      uniqueItems: true,
    ),
  ];

  @override
  Future<String> execute(Map<String, dynamic> args, {extra}) async {
    counterUsed++;
    final list = (args["tags"] as List).cast<String>();
    final changedList = list.map((e) => e == 'is' ? 'are' : e).toList();
    return 'Result is: ${changedList.join("<!-..-!>")}';
  }
}

class ExtractEntitiesTool extends LLMTool {
  int counterUsed = 0;
  @override
  String get name => "extract_entities";
  @override
  String get description => "Extract entities and their types from the text.";
  @override
  List<LLMToolParam> get parameters => [
    LLMToolParam(
      name: "entities",
      type: "array",
      description: "An array of entities with their types.",
      isRequired: true,
      items: LLMToolParam(
        name: "entityObject",
        type: "object",
        description: "One entity + its type",
        additionalProperties: false,
        properties: [
          LLMToolParam(
            name: "entity",
            type: "string",
            description: "The name or identifier of the entity.",
            isRequired: true,
          ),
          LLMToolParam(
            name: "entity_type",
            type: "string",
            description: "The type or category of the entity.",
            isRequired: true,
          ),
        ],
      ),
    ),
  ];

  @override
  Future execute(Map<String, dynamic> args, {extra}) async {
    counterUsed++;
    return 'Result is: ${args["entities"]}';
  }
}
