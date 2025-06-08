import 'package:dart_ollama/dart_ollama.dart';

void main() async {
  final repository = OllamaChatRepository(baseUrl: 'http://localhost:11434');

  // Example 1: Using thinking on a non-thinking model
  print('Example 1: Trying to use thinking on a non-thinking model...');
  try {
    final stream = repository.streamChat(
      'qwen2.5:0.5b', // Non-thinking model
      messages: [
        LLMMessage(role: LLMRole.user, content: 'Hello'),
      ],
      think: true, // This will cause Ollama to return an error, which we catch and convert to ThinkingNotAllowed
    );
    await for (final chunk in stream) {
      // This should not be reached
    }
  } on ThinkingNotAllowed catch (e) {
    print('Caught expected error: $e');
  }

  // Example 2: Using tools on a non-chat model  
  print('\nExample 2: Trying to use tools on a non-chat model...');
  final calculatorTool = TestCalculatorTool();
  final toolRepository = OllamaChatRepository(
    baseUrl: 'http://localhost:11434',
    tools: [calculatorTool],
  );
  
  try {
    final stream = toolRepository.streamChat(
      'nomic-embed-text', // Embedding model that doesn't support chat at all
      messages: [
        LLMMessage(role: LLMRole.user, content: 'What is 2 + 2?'),
      ],
    );
    await for (final chunk in stream) {
      // This should not be reached
    }
  } catch (e) {
    print('Caught expected error: $e');
    // Note: This will be a generic Exception since embedding models don't support chat at all
    // In practice, most chat models actually support tools, so true ToolsNotAllowed errors are rare
  }

  // Example 3: Normal usage (this should work fine)
  print('\nExample 3: Normal usage with a compatible model...');
  try {
    final stream = repository.streamChat(
      'qwen3:0.6b', // Thinking model
      messages: [
        LLMMessage(role: LLMRole.user, content: 'Hello'),
      ],
      think: true, // This should work fine
    );
    print('Successfully started streaming with thinking model');
    // Don't actually consume the stream in this example
  } catch (e) {
    print('Unexpected error: $e');
  }

  print('\nNote: The new approach is more efficient as it:');
  print('- Makes only one API call (no upfront capability checking)');  
  print('- Relies on Ollama\'s actual error responses');
  print('- Converts specific error messages to typed exceptions');
}

// Simple test tool for the example
class TestCalculatorTool extends LLMTool {
  @override
  String get name => 'calculator';

  @override
  Future execute(Map<String, dynamic> args, {extra}) async {
    return 'Result: 4';
  }

  @override
  String get description => 'Perform basic math operations';

  @override
  List<LLMToolParam> get parameters => [
    LLMToolParam(name: 'operation', type: 'string', description: 'The operation', isRequired: true),
    LLMToolParam(name: 'a', type: 'number', description: 'First operand', isRequired: true),
    LLMToolParam(name: 'b', type: 'number', description: 'Second operand', isRequired: true),
  ];
} 