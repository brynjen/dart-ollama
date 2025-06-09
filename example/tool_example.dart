import 'package:dart_ollama/dart_ollama.dart';

Future<void> main() async {
  print('🔧 Dart Ollama Tool Usage Example\n');

  // Create the chat repository with tools
  final calculatorTool = CalculatorTool();
  final formatterTool = ResultFormatterTool();

  final chatRepository = OllamaChatRepository(
    baseUrl: 'http://localhost:11434',
    tools: [calculatorTool, formatterTool],
  );

  final ollamaRepository = OllamaRepository(baseUrl: 'http://localhost:11434');

  // Ensure the model is available
  await _ensureModelAvailable(ollamaRepository, 'qwen3:0.6b');

  print('💬 Starting conversation with tools...\n');

  // Example 1: Simple calculation
  await _runCalculationExample(chatRepository);

  print('\n${'=' * 50}\n');

  // Example 2: Complex calculation with formatting
  await _runComplexCalculationExample(chatRepository);
}

Future<void> _runCalculationExample(OllamaChatRepository chatRepository) async {
  print('📊 Example 1: Simple Calculator Tool');
  print('Question: What is 15 * 7?');

  final stream = chatRepository.streamChat(
    'qwen3:0.6b',
    messages: [
      LLMMessage(
        role: LLMRole.system,
        content:
            'You are a helpful assistant. Use the calculator tool when you need to perform mathematical operations. Be concise.',
      ),
      LLMMessage(role: LLMRole.user, content: 'What is 15 * 7?'),
    ],
    think: true,
  );

  String thinkingContent = '';
  String responseContent = '';

  await for (final chunk in stream) {
    thinkingContent += chunk.message?.thinking ?? '';
    responseContent += chunk.message?.content ?? '';
  }

  print('\n🤔 Model thinking:');
  print(thinkingContent.isEmpty ? '(No thinking output)' : thinkingContent);
  print('\n💭 Response:');
  print(responseContent);
}

Future<void> _runComplexCalculationExample(
  OllamaChatRepository chatRepository,
) async {
  print('🔢 Example 2: Complex Calculation with Formatting');
  print('Question: Calculate (25 + 15) ÷ 8 and format the result nicely');

  final stream = chatRepository.streamChat(
    'qwen3:0.6b',
    messages: [
      LLMMessage(
        role: LLMRole.system,
        content:
            'You are a helpful assistant. Use the calculator and formatter tools when appropriate. First calculate, then format the result.',
      ),
      LLMMessage(
        role: LLMRole.user,
        content:
            'Calculate (25 + 15) ÷ 8 and format the result in a nice way using the formatter tool',
      ),
    ],
    think: true,
  );

  String thinkingContent = '';
  String responseContent = '';

  await for (final chunk in stream) {
    thinkingContent += chunk.message?.thinking ?? '';
    responseContent += chunk.message?.content ?? '';
  }

  print('\n🤔 Model thinking:');
  print(thinkingContent.isEmpty ? '(No thinking output)' : thinkingContent);
  print('\n💭 Response:');
  print(responseContent);
}

Future<void> _ensureModelAvailable(
  OllamaRepository repository,
  String modelName,
) async {
  final models = await repository.models();
  if (!models.any((model) => model.name == modelName)) {
    print('📥 Model $modelName not found. Pulling...');
    final modelStream = repository.pullModel(modelName);
    await for (final progress in modelStream) {
      final statusLine = progress.status;
      if (progress.total != null && progress.completed != null) {
        final percentage = (progress.progress * 100).toStringAsFixed(1);
        final bar = _buildProgressBar(progress.progress, 30);
        print('$statusLine $bar $percentage%');
      } else {
        print(statusLine);
      }
    }
    print('\n✅ Model $modelName pulled successfully.');
  } else {
    print('✅ Model $modelName is available.');
  }
}

String _buildProgressBar(double progress, int length) {
  final filledLength = (progress * length).floor();
  final emptyLength = length - filledLength;
  return '[${'=' * filledLength}${' ' * emptyLength}]';
}

/// A calculator tool that can perform basic mathematical operations
class CalculatorTool extends LLMTool {
  @override
  String get name => 'calculator';

  @override
  String get description =>
      'Perform basic mathematical operations like addition, subtraction, multiplication, and division';

  @override
  List<LLMToolParam> get parameters => [
    LLMToolParam(
      name: 'operation',
      type: 'string',
      description: 'The mathematical operation to perform',
      enums: ['add', 'subtract', 'multiply', 'divide'],
      isRequired: true,
    ),
    LLMToolParam(
      name: 'a',
      type: 'number',
      description: 'First number',
      isRequired: true,
    ),
    LLMToolParam(
      name: 'b',
      type: 'number',
      description: 'Second number',
      isRequired: true,
    ),
  ];

  @override
  Future<String> execute(Map<String, dynamic> args, {dynamic extra}) async {
    final operation = args['operation'] as String;
    final a = (args['a'] as num).toDouble();
    final b = (args['b'] as num).toDouble();

    double result;
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
          return 'Error: Cannot divide by zero';
        }
        result = a / b;
        break;
      default:
        return 'Error: Unknown operation $operation';
    }

    return 'Calculation result: $a $operation $b = $result';
  }
}

/// A formatter tool that formats mathematical results nicely
class ResultFormatterTool extends LLMTool {
  @override
  String get name => 'result_formatter';

  @override
  String get description =>
      'Format mathematical results in a nice, readable way with decorations';

  @override
  List<LLMToolParam> get parameters => [
    LLMToolParam(
      name: 'result',
      type: 'string',
      description: 'The mathematical result to format',
      isRequired: true,
    ),
    LLMToolParam(
      name: 'style',
      type: 'string',
      description: 'The formatting style to use',
      enums: ['simple', 'decorated', 'boxed'],
      isRequired: false,
    ),
  ];

  @override
  Future<String> execute(Map<String, dynamic> args, {dynamic extra}) async {
    final result = args['result'] as String;
    final style = args['style'] as String? ?? 'decorated';

    switch (style) {
      case 'simple':
        return '✅ Result: $result';
      case 'boxed':
        final line = '═' * (result.length + 10);
        return '╔$line╗\n║    $result    ║\n╚$line╝';
      case 'decorated':
      default:
        return '🎯 **RESULT**: $result 🎯';
    }
  }
}
