import 'dart:convert';
import 'dart:io';

import '../dto/ollama_model.dart';

/// Handles communicating with Ollama letting you pull models and check if they are there
class OllamaRepository {
  OllamaRepository({
    this.baseUrl = "http://localhost:11434",
    HttpClient? httpClient,
  }) : httpClient = httpClient ?? HttpClient();
  final String baseUrl;
  final HttpClient httpClient;

  /// List all locally available models
  /// GET /api/tags
  Future<List<OllamaModel>> models() async {
    final response = await _sendRequest('GET', Uri.parse('$baseUrl/api/tags'));
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body);

    // The response has a "models" key that contains the array of models
    final List<dynamic> modelsJson = json['models'] ?? [];
    return modelsJson.map((model) => OllamaModel.fromJson(model)).toList();
  }

  /// Show information about a specific model
  /// POST /api/show
  Future<OllamaModelInfo> showModel(String modelName) async {
    final response = await _sendRequest(
      'POST',
      Uri.parse('$baseUrl/api/show'),
      body: {'model': modelName},
    );
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body);
    return OllamaModelInfo.fromJson(json);
  }

  /// Pull a model from the ollama library
  /// POST /api/pull
  /// Returns a stream of progress updates
  Stream<OllamaPullProgress> pullModel(String modelName) async* {
    final request = await httpClient.openUrl(
      'POST',
      Uri.parse('$baseUrl/api/pull'),
    );
    request.headers.add(HttpHeaders.contentTypeHeader, 'application/json');
    request.add(utf8.encode(json.encode({'model': modelName})));

    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('Failed to pull model: ${response.statusCode}');
    }

    await for (final chunk in response.transform(utf8.decoder)) {
      // Split by newlines to handle multiple JSON objects in one chunk
      final lines = chunk.split('\n').where((line) => line.trim().isNotEmpty);
      for (final line in lines) {
        try {
          final jsonData = jsonDecode(line);
          yield OllamaPullProgress.fromJson(jsonData);
        } catch (e) {
          // Skip malformed JSON lines
          continue;
        }
      }
    }
  }

  /// Get the version of Ollama
  /// GET /api/version
  Future<OllamaVersion> version() async {
    final response = await _sendRequest(
      'GET',
      Uri.parse('$baseUrl/api/version'),
    );
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body);
    return OllamaVersion.fromJson(json);
  }

  Future<HttpClientResponse> _sendRequest(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final request = await httpClient.openUrl(method, uri);
    request.headers.add(HttpHeaders.contentTypeHeader, 'application/json');
    if (body != null) {
      request.add(utf8.encode(json.encode(body)));
    }
    final response = await request.close();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed with status ${response.statusCode}');
    }

    return response;
  }
}
