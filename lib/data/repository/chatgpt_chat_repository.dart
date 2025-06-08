import 'dart:convert';
import 'dart:io';

import 'package:dart_ollama/dart_ollama.dart';
import 'package:dart_ollama/data/dto/gpt_embedding_response.dart';
import 'package:dart_ollama/data/dto/gpt_response.dart';
import 'package:dart_ollama/data/dto/gpt_stream_decoder.dart';
import 'package:dart_ollama/domain/model/llm_embedding.dart';

class ChatGPTChatRepository extends LLMChatRepository {
  ChatGPTChatRepository({
    required this.apiKey,
    this.baseUrl = "https://api.openai.com",
    this.tools = const [],
    this.maxToolAttempts = 25,
    HttpClient? httpClient,
  }) : httpClient = httpClient ?? HttpClient();
  final String baseUrl;

  /// The API key to use for openAI
  final String apiKey;

  /// Available tools the repository can use.
  final List<LLMTool> tools;

  final HttpClient httpClient;

  /// The maximum number of tool attempts to make. for a single request.
  final int maxToolAttempts;

  Uri get uri => Uri.parse('$baseUrl/v1/chat/completions');

  @override
  List<LLMTool> availableTools() => tools;

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
      'messages': messages.map((msg) => msg.toJson()).toList(growable: false),
      'stream': true,
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
          // Read the error response body
          final errorBody = await response.transform(utf8.decoder).join();
          throw Exception('OpenAI API error ${response.statusCode}: $errorBody');
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
    request.headers.add(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
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
    Map<String, GPTToolCall> toolsToCall = {};
    await for (final output in response.transform(utf8.decoder).transform(GPTStreamDecoder.decoder)) {
      if (output != '[DONE]') {
        try {
          final chunk = GPTChunk.fromJson(json.decode(output));
          for (final toolCall in chunk.choices[0].delta.toolCalls ?? <GPTToolCall>[]) {
            if (toolCall.id != null) {
              toolsToCall[toolCall.id!] = toolCall;
            } else {
              final lastId = toolsToCall.keys.last;
              final updatedTool = toolsToCall[lastId]?.copyWith(newFunction: toolCall.function);
              toolsToCall[lastId] = updatedTool!;
            }
          }
          final finishReason = chunk.choices[0].finishReason;
          final content = chunk.choices[0].delta.content;

          if (content != null && finishReason == null) {
            yield chunk;
          }
          if (finishReason != null) {
            if (finishReason == 'tool_calls') {
              // First add the assistant's message with tool calls
              final toolCallsList = toolsToCall.values
                  .map(
                    (toolCall) => {
                      'id': toolCall.id,
                      'type': 'function',
                      'function': {'name': toolCall.function.name, 'arguments': toolCall.function.arguments},
                    },
                  )
                  .toList();

              messages.add(LLMMessage(content: null, role: LLMRole.assistant, toolCalls: toolCallsList));

              // Then add tool response messages
              for (final toolCall in toolsToCall.values) {
                final function = toolCall.function;
                final tool = tools.firstWhere((t) => t.name == toolCall.function.name);
                final toolResponse =
                    await tool.execute(json.decode(function.arguments), extra: extra) ??
                    'Unable to use not-existing tool ${function.name}';
                messages.add(LLMMessage(content: toolResponse, role: LLMRole.tool, toolCallId: toolCall.id));
                toolAttempts--;
              }
              yield* streamChat(model, messages: messages, toolAttempts: toolAttempts, extra: extra);
            } else {
              print('finishReason: $finishReason');
            }
          }
        } catch (e) {
          print('Failed: $e');
        }
      }
    }
  }

  @override
  Future<List<LLMEmbedding>> embed({
    required String model,
    required List<String> messages,
    Map<String, dynamic> options = const {},
  }) async {
    final body = {'model': model, 'input': messages};
    final response = await _sendRequest('POST', Uri.parse('$baseUrl/v1/embeddings'), body: body);
    switch (response.statusCode) {
      case HttpStatus.ok:
        final responseBody = await response.transform(utf8.decoder).join();
        return ChatGPTEmbeddingsResponse.fromJson(json.decode(responseBody)).toLLMEmbedding;
      default:
        stdout.writeln('\nError generating embedding: ${response.statusCode}');
        throw response;
    }
  }
}
