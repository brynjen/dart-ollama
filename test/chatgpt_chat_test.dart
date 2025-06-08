import 'dart:io';

import 'package:dart_ollama/dart_ollama.dart';
import 'package:test/test.dart';
import 'package:dotenv/dotenv.dart';

void main() {
  group('Testing the working of the library against a local ollama instance', () {
    late LLMChatRepository repository;
    String model = 'gpt-3.5-turbo';
    String embeddingModel = 'text-embedding-3-small';
    late String apiKey;

    setUpAll(() async {
      final env = DotEnv(includePlatformEnvironment: true);
      if (File('.env').existsSync()) {
        env.load();
        final storedApiKey = env['OPENAI_API_KEY'];
        if (storedApiKey == null) {
          throw 'OPENAI_API_KEY is not set in environment';
        }
        apiKey = storedApiKey;
      } else {
        final storedApiKey = Platform.environment['OPENAI_API_KEY'];
        if (storedApiKey == null) {
          throw 'OPENAI_API_KEY is not set in environment';
        }
        apiKey = storedApiKey;
      }
    });
    
    setUp(() {
      repository = ChatGPTChatRepository(apiKey: apiKey);
    });

    group('General tests', () {
      test('Test regular streaming works', () async {
        final stream = repository.streamChat(
          model,
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
        expect(thinkingContent, isEmpty);
        expect(content, isNotEmpty);
        print('Content: $content');
      });
    });

    group('Tool tests', () {
      test('Test tool works', () async {
        final tool = TestCalculatorTool();
        expect(tool.counterUsed, 0);
        repository = ChatGPTChatRepository(apiKey: apiKey, tools: [tool]);
        final stream = repository.streamChat(
          model,
          messages: [
            LLMMessage(role: LLMRole.system, content: 'Answer short and consise. Use tools.'),
            LLMMessage(role: LLMRole.user, content: 'What is 2 + 2?'),
          ],
        );
        String combinedContent = '';
        await for (final chunk in stream) {
          combinedContent += chunk.message?.content ?? '';
        }
        expect(tool.counterUsed, 1);
        expect(combinedContent, isNotEmpty);
        print('Content: $combinedContent');
      });
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
  });
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
