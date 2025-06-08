import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_ollama/data/dto/ollama_embedding_response.dart';
import 'package:dart_ollama/data/dto/ollama_response.dart';
import 'package:dart_ollama/domain/model/llm_chunk.dart';
import 'package:dart_ollama/domain/model/llm_embedding.dart';
import 'package:dart_ollama/domain/model/llm_message.dart';
import 'package:dart_ollama/domain/model/llm_tool.dart';
import 'package:dart_ollama/domain/repository/llm_chat_repository.dart';

class OllamaChatRepository extends LLMChatRepository {
  OllamaChatRepository({
    this.baseUrl = "http://localhost:11434",
    this.tools = const [],
    this.maxToolAttempts = 25,
    HttpClient? httpClient,
  }) : httpClient = httpClient ?? HttpClient();
  final String baseUrl;

  /// Available tools the repository can use.
  final List<LLMTool> tools;

  final HttpClient httpClient;

  /// The maximum number of tool attempts to make. for a single request.
  final int maxToolAttempts;

  Uri get uri => Uri.parse('$baseUrl/api/chat');

  @override
  Stream<LLMChunk> streamChat(
    String model, {
    required List<LLMMessage> messages,
    dynamic extra,
    int? toolAttempts,
    bool think = false,
  }) async* {
    final body = {
      'model': model,
      'messages': messages.map((msg) => _ollamaMessageToJson(msg)).toList(growable: false),
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
          yield* toLLMStream(response, model: model, messages: messages, toolAttempts: toolAttempts ?? maxToolAttempts);
        default:
          // TODO: Proper error handling
          stdout.writeln('\nError generating stream: ${response.statusCode}');
          throw response;
      }
    } on HttpClientResponse catch (_) {
      //final error = await e.transform(utf8.decoder).join();
      rethrow;
    }
  }

  Future<HttpClientResponse> _sendRequest(String method, Uri uri, {Map<String, dynamic>? body}) async {
    final request = await httpClient.openUrl(method, uri);
    request.bufferOutput = false;
    request.headers.add(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.add(HttpHeaders.acceptHeader, 'text/event-stream');
    if (body != null) {
      request.add(utf8.encode(json.encode(body)));
    }
    return request.close();
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

    await for (final line in response.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isNotEmpty) {
        try {
          final jsonData = json.decode(line);
          final chunk = OllamaChunk.fromJson(jsonData);
          yield chunk;

          if (chunk.message?.toolCalls != null && chunk.message!.toolCalls!.isNotEmpty) {
            collectedToolCalls.addAll(chunk.message!.toolCalls!);
          }
          if (chunk.done == true && collectedToolCalls.isNotEmpty) {
            for (final toolCall in collectedToolCalls) {
              final tool = tools.firstWhere(
                (t) => t.name == toolCall.name,
                orElse: () => throw Exception('Tool ${toolCall.name} not found'),
              );
              final toolResponse =
                  await tool.execute(json.decode(toolCall.arguments), extra: extra) ??
                  'Tool ${toolCall.name} returned null';
              workingMessages.add(LLMMessage(content: toolResponse, role: LLMRole.tool, toolCallId: toolCall.id));
            }

            if (toolAttempts > 0) {
              yield* streamChat(model, messages: workingMessages, extra: extra, toolAttempts: toolAttempts - 1);
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
    final json = <String, dynamic>{'role': message.role.name, 'content': message.content ?? ''};

    if (message.toolCallId != null) json['tool_call_id'] = message.toolCallId;
    if (message.toolCalls != null) json['tool_calls'] = message.toolCalls;

    return json;
  }

  @override
  Future<List<LLMEmbedding>> embed({
    required String model,
    required List<String> messages,
    Map<String, dynamic> options = const {},
  }) async {
    final body = {'model': model, 'input': messages, 'options': options};
    final response = await _sendRequest('POST', Uri.parse('$baseUrl/api/embed'), body: body);
    switch (response.statusCode) {
      case HttpStatus.ok:
        final responseBody = await response.transform(utf8.decoder).join();
        return OllamaEmbeddingResponse.fromJson(json.decode(responseBody)).toLLMEmbedding;
      default:
        stdout.writeln('\nError generating embedding: ${response.statusCode}');
        throw response;
    }
  }
}
