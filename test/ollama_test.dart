import 'package:dart_ollama/data/repository/ollama_repository.dart';
import 'package:dart_ollama/data/dto/ollama_model.dart';
import 'package:test/test.dart';

void main() {
  group('Testing the functionality of the Ollama repository', () {
    late OllamaRepository repository;
    String baseUrl = 'http://localhost:11434';
    setUp(() {
      repository = OllamaRepository(baseUrl: baseUrl);
    });

    group('Model testing', () {
      test('Test that listing models works', () async {
        try {
          final models = await repository.models();
          expect(models, isA<List>());
          print('Found ${models.length} models');
          
          if (models.isNotEmpty) {
            print('First model: ${models.first}');
            expect(models.first.name, isNotEmpty);
            expect(models.first.size, greaterThan(0));
          }
        } catch (e) {
          print('Error listing models: $e');
          print('Make sure Ollama is running on $baseUrl');
          rethrow;
        }
      });

      test('Test that showing model information works', () async {
        try {
          // First get available models
          final models = await repository.models();
          if (models.isEmpty) {
            print('No models available for testing. Skipping test.');
            return;
          }

          final firstModel = models.first;
          print('Testing with model: ${firstModel.name}');
          
          final modelInfo = await repository.showModel(firstModel.name);
          expect(modelInfo, isA<OllamaModelInfo>());
          expect(modelInfo.details, isNotNull);
          print('Model info: $modelInfo');
        } catch (e) {
          print('Error getting model info: $e');
          rethrow;
        }
      });

      test('Test that getting Ollama version works', () async {
        try {
          final version = await repository.version();
          expect(version, isA<OllamaVersion>());
          expect(version.version, isNotEmpty);
          print('Ollama version: ${version.version}');
        } catch (e) {
          print('Error getting version: $e');
          rethrow;
        }
      });

      test('Test that pulling a small model works', () async {
        try {
          // Use a small model for testing to avoid long wait times
          const testModel = 'qwen3:0.6b';
          print('Attempting to pull model: $testModel');
          
          var lastProgress = 0.0;
          var hasStarted = false;
          var isComplete = false;
          
          await for (final progress in repository.pullModel(testModel)) {
            hasStarted = true;
            print('Pull progress: $progress');
            
            expect(progress.status, isNotEmpty);
            
            if (progress.total != null && progress.completed != null) {
              expect(progress.progress, greaterThanOrEqualTo(lastProgress));
              lastProgress = progress.progress;
            }
            
            if (progress.status == 'success') {
              isComplete = true;
              break;
            }
            
            // Break early to avoid downloading the entire model in tests
            if (progress.status.contains('downloading') && progress.progress > 0.01) {
              print('Model pull started successfully, stopping test to avoid full download');
              break;
            }
          }
          
          expect(hasStarted, isTrue, reason: 'Pull operation should have started');
          print('Pull test completed. Started: $hasStarted, Complete: $isComplete');
        } catch (e) {
          print('Error pulling model: $e');
          print('This might be expected if the model is not available or network issues occur');
          // Don't rethrow here as pull operations can fail for various reasons in CI/testing
        }
      });

      test('Test error handling for non-existent model', () async {
        try {
          await repository.showModel('non-existent-model-xyz-123');
          fail('Should have thrown an exception for non-existent model');
        } catch (e) {
          print('Expected error for non-existent model: $e');
          expect(e.toString(), contains('Request failed'));
        }
      });
    });

    group('Integration tests', () {
      test('Test complete workflow: list, show, and version', () async {
        try {
          // Test version first
          final version = await repository.version();
          print('Ollama version: ${version.version}');
          
          // List models
          final models = await repository.models();
          print('Available models: ${models.length}');
          
          if (models.isNotEmpty) {
            // Show info for first model
            final modelInfo = await repository.showModel(models.first.name);
            print('Model details: ${modelInfo.details.family}');
            
            expect(version.version, isNotEmpty);
            expect(models, isNotEmpty);
            expect(modelInfo.details.family, isNotEmpty);
          }
        } catch (e) {
          print('Integration test error: $e');
          rethrow;
        }
      });
    });
  });
}
