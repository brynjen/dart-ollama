import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../dto/ollama_embedding_response.dart';
import '../dto/ollama_response.dart';
import '../../domain/exceptions/ollama_exceptions.dart';
import '../../domain/model/llm_chunk.dart';
import '../../domain/model/llm_embedding.dart';
import '../../domain/model/llm_message.dart';
import '../../domain/model/llm_tool.dart';
import '../../domain/repository/llm_chat_repository.dart';

class OllamaChatRepository extends LLMChatRepository {
  OllamaChatRepository({
    this.baseUrl = "http://localhost:11434",
    this.tools = const [],
    this.maxToolAttempts = 25,
    HttpClient? httpClient,
  }) : httpClient = httpClient ?? HttpClient() {
    // Set reasonable timeouts for large image payloads
    this.httpClient.connectionTimeout = const Duration(seconds: 120);
    this.httpClient.idleTimeout = const Duration(seconds: 120);
  }
  final String baseUrl;

  /// Available tools the repository can use.
  final List<LLMTool> tools;

  final HttpClient httpClient;

  /// The maximum number of tool attempts to make. for a single request.
  final int maxToolAttempts;

  Uri get uri => Uri.parse('$baseUrl/api/chat');

  /// Check if a model supports vision by querying its model info
  /// Vision models have "vision" in their capabilities array
  Future<bool> _supportsVision(String model) async {
    try {
      final response = await _sendRequest(
        'POST',
        Uri.parse('$baseUrl/api/show'),
        body: {'model': model},
      );

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body);

        // Check if model has vision capability
        final capabilities = json['capabilities'] as List<dynamic>?;
        if (capabilities != null) {
          return capabilities.contains('vision');
        }
      }

      // If we can't determine, assume it doesn't support vision to be safe
      return false;
    } catch (e) {
      // If we can't determine, assume it doesn't support vision to be safe
      return false;
    }
  }

  @override
  Stream<LLMChunk> streamChat(
    String model, {
    required List<LLMMessage> messages,
    dynamic extra,
    int? toolAttempts,
    bool think = false,
  }) async* {
    // If images are present, check if the model supports vision
    if (messages.any((msg) => msg.images != null && msg.images!.isNotEmpty)) {
      if (!(await _supportsVision(model))) {
        throw VisionNotAllowed(
          model,
          'Model $model does not support vision/images',
        );
      }
    }

    final body = {
      'model': model,
      'messages': messages
          .map((msg) => _ollamaMessageToJson(msg))
          .toList(growable: false),
      'stream': true,
      'think': think,
    };
    if (tools.isNotEmpty) {
      body['tools'] = tools.map((tool) => tool.toJson).toList(growable: false);
    }
    final response = await _sendRequest('POST', uri, body: body);

    try {
      switch (response.statusCode) {
        case HttpStatus.ok:
          yield* toLLMStream(
            response,
            model: model,
            messages: messages,
            toolAttempts: toolAttempts ?? maxToolAttempts,
          );
        case HttpStatus.badRequest:
          // Handle 400 errors which might be feature not supported
          final errorBody = await response.transform(utf8.decoder).join();
          await _handleBadRequestError(
            errorBody,
            model,
            think,
            tools.isNotEmpty,
          );
          break;
        default:
          throw response;
      }
    } on HttpClientResponse catch (_) {
      rethrow;
    }
  }

  /// Handle 400 Bad Request errors and throw appropriate exceptions
  Future<void> _handleBadRequestError(
    String errorBody,
    String model,
    bool thinkRequested,
    bool toolsRequested,
  ) async {
    try {
      final errorData = json.decode(errorBody);
      final errorMessage = errorData['error'] as String? ?? '';

      // Check for thinking not supported error
      if (thinkRequested &&
          errorMessage.contains('does not support thinking')) {
        throw ThinkingNotAllowed(
          model,
          'Model $model does not support thinking',
        );
      }

      // Check for tools not supported error
      if (toolsRequested && errorMessage.contains('does not support tools')) {
        throw ToolsNotAllowed(model, 'Model $model does not support tools');
      }

      // Check for chat not supported error (like embedding models)
      if (errorMessage.contains('does not support chat')) {
        throw Exception(
          'Model $model does not support chat - use a chat/completion model instead',
        );
      }

      // If it's not a specific feature support error, throw a generic error
      throw Exception('Bad request: $errorMessage');
    } catch (e) {
      if (e is ThinkingNotAllowed || e is ToolsNotAllowed) {
        rethrow;
      }
      throw Exception('Bad request: $errorBody');
    }
  }

  Future<HttpClientResponse> _sendRequest(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final request = await httpClient.openUrl(method, uri);
    request.bufferOutput = false;
    request.headers.add(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.add(HttpHeaders.acceptHeader, 'text/event-stream');

    if (body != null) {
      final bodyJson = json.encode(body);
      final bodyBytes = utf8.encode(bodyJson);

      // Set content length for large payloads
      request.headers.add(
        HttpHeaders.contentLengthHeader,
        bodyBytes.length.toString(),
      );

      // For large payloads, write in chunks to avoid buffer issues
      if (bodyBytes.length > 1024 * 1024) {
        // 1MB threshold
        const chunkSize = 64 * 1024; // 64KB chunks
        for (int i = 0; i < bodyBytes.length; i += chunkSize) {
          final end = (i + chunkSize < bodyBytes.length)
              ? i + chunkSize
              : bodyBytes.length;
          request.add(bodyBytes.sublist(i, end));
        }
      } else {
        request.add(bodyBytes);
      }
    }

    // Add timeout for large requests - adjust based on payload size
    final timeoutDuration =
        body != null && json.encode(body).length > 1024 * 1024
        ? const Duration(seconds: 300) // 5 minutes for large images
        : const Duration(minutes: 2);

    return request.close().timeout(
      timeoutDuration,
      onTimeout: () {
        request.abort();
        throw TimeoutException('Request timed out', timeoutDuration);
      },
    );
  }

  Stream<LLMChunk> toLLMStream(
    HttpClientResponse response, {
    required String model,
    required List<LLMMessage> messages,
    dynamic extra,
    Map<String, dynamic> options = const {},
    int toolAttempts = 5,
  }) async* {
    List<LLMMessage> workingMessages = List.from(messages);
    List<dynamic> collectedToolCalls = [];

    await for (final line
        in response.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isNotEmpty) {
        try {
          final chunk = OllamaChunk.fromJson(json.decode(line));
          yield chunk;

          if (chunk.message?.toolCalls != null &&
              chunk.message!.toolCalls!.isNotEmpty) {
            collectedToolCalls.addAll(chunk.message!.toolCalls!);
          }
          if (chunk.done == true && collectedToolCalls.isNotEmpty) {
            for (final toolCall in collectedToolCalls) {
              final tool = tools.firstWhere(
                (t) => t.name == toolCall.name,
                orElse: () =>
                    throw Exception('Tool ${toolCall.name} not found'),
              );
              final toolResponse =
                  await tool.execute(
                    json.decode(toolCall.arguments),
                    extra: extra,
                  ) ??
                  'Tool ${toolCall.name} returned null';
              workingMessages.add(
                LLMMessage(
                  content: toolResponse,
                  role: LLMRole.tool,
                  toolCallId: toolCall.id,
                ),
              );
            }

            if (toolAttempts > 0) {
              yield* streamChat(
                model,
                messages: workingMessages,
                extra: extra,
                toolAttempts: toolAttempts - 1,
              );
              return;
            }
          }
        } catch (_) {}
      }
    }
  }

  @override
  List<LLMTool> availableTools() => tools;

  Map<String, dynamic> _ollamaMessageToJson(LLMMessage message) {
    final json = <String, dynamic>{
      'role': message.role.name,
      'content': message.content ?? '',
    };

    if (message.toolCallId != null) json['tool_call_id'] = message.toolCallId;
    if (message.toolCalls != null) json['tool_calls'] = message.toolCalls;
    if (message.images != null && message.images!.isNotEmpty)
      json['images'] = message.images;

    return json;
  }

  @override
  Future<List<LLMEmbedding>> embed({
    required String model,
    required List<String> messages,
    Map<String, dynamic> options = const {},
  }) async {
    final body = {'model': model, 'input': messages, 'options': options};
    final response = await _sendRequest(
      'POST',
      Uri.parse('$baseUrl/api/embed'),
      body: body,
    );
    switch (response.statusCode) {
      case HttpStatus.ok:
        final responseBody = await response.transform(utf8.decoder).join();
        return OllamaEmbeddingResponse.fromJson(
          json.decode(responseBody),
        ).toLLMEmbedding;
      default:
        stdout.writeln('\nError generating embedding: ${response.statusCode}');
        throw response;
    }
  }
}
