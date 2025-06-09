import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../domain/repository/llm_chat_repository.dart';
import '../../domain/model/llm_chunk.dart';
import '../../domain/model/llm_message.dart';
import '../../domain/model/llm_tool.dart';
import '../dto/gpt_embedding_response.dart';
import '../dto/gpt_response.dart';
import '../dto/gpt_stream_decoder.dart';
import '../../domain/model/llm_embedding.dart';

/// Repository for chatting with ChatGPT. Add api key and it should just work. For a reference of model names,
/// see https://platform.openai.com/docs/models/overview
class ChatGPTChatRepository extends LLMChatRepository {
  ChatGPTChatRepository({
    required this.apiKey,
    this.baseUrl = "https://api.openai.com",
    this.tools = const [],
    this.maxToolAttempts = 25,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  final String baseUrl;

  /// The API key to use for openAI
  final String apiKey;

  /// Available tools the repository can use.
  final List<LLMTool> tools;

  final http.Client httpClient;

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
    final response = await _sendStreamingRequest('POST', uri, body: body);
    try {
      switch (response.statusCode) {
        case 200: // HttpStatus.ok
          yield* toLLMStream(
            response,
            model: model,
            messages: messages,
            toolAttempts: toolAttempts ?? maxToolAttempts,
          );
        default:
          // Read the error response body
          final errorBody = await response.stream
              .transform(utf8.decoder)
              .join();
          throw Exception(
            'OpenAI API error ${response.statusCode}: $errorBody',
          );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<http.StreamedResponse> _sendStreamingRequest(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final request = http.StreamedRequest(method, uri);
    request.headers['content-type'] = 'application/json';
    request.headers['accept'] = 'text/event-stream';
    request.headers['authorization'] = 'Bearer $apiKey';

    if (body != null) {
      final bodyBytes = utf8.encode(json.encode(body));
      request.headers['content-length'] = bodyBytes.length.toString();
      request.sink.add(bodyBytes);
    }
    request.sink.close();

    return httpClient.send(request);
  }

  Future<http.Response> _sendNonStreamingRequest(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final headers = {
      'content-type': 'application/json',
      'accept': 'application/json',
      'authorization': 'Bearer $apiKey',
    };

    final response = method.toUpperCase() == 'POST'
        ? await httpClient.post(
            uri,
            headers: headers,
            body: body != null ? json.encode(body) : null,
          )
        : await httpClient.get(uri, headers: headers);

    return response;
  }

  Stream<LLMChunk> toLLMStream(
    http.StreamedResponse response, {
    required String model,
    required List<LLMMessage> messages,
    dynamic extra,
    Map<String, dynamic> options = const {},
    int toolAttempts = 5,
  }) async* {
    Map<String, GPTToolCall> toolsToCall = {};
    await for (final output
        in response.stream
            .transform(utf8.decoder)
            .transform(GPTStreamDecoder.decoder)) {
      if (output != '[DONE]') {
        try {
          final chunk = GPTChunk.fromJson(json.decode(output));
          for (final toolCall
              in chunk.choices[0].delta.toolCalls ?? <GPTToolCall>[]) {
            if (toolCall.id != null) {
              toolsToCall[toolCall.id!] = toolCall;
            } else {
              final lastId = toolsToCall.keys.last;
              final updatedTool = toolsToCall[lastId]?.copyWith(
                newFunction: toolCall.function,
              );
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
                      'function': {
                        'name': toolCall.function.name,
                        'arguments': toolCall.function.arguments,
                      },
                    },
                  )
                  .toList();

              messages.add(
                LLMMessage(
                  content: null,
                  role: LLMRole.assistant,
                  toolCalls: toolCallsList,
                ),
              );

              // Then add tool response messages
              for (final toolCall in toolsToCall.values) {
                final function = toolCall.function;
                final tool = tools.firstWhere(
                  (t) => t.name == toolCall.function.name,
                );
                final toolResponse =
                    await tool.execute(
                      json.decode(function.arguments),
                      extra: extra,
                    ) ??
                    'Unable to use not-existing tool ${function.name}';
                messages.add(
                  LLMMessage(
                    content: toolResponse,
                    role: LLMRole.tool,
                    toolCallId: toolCall.id,
                  ),
                );
                toolAttempts--;
              }
              yield* streamChat(
                model,
                messages: messages,
                toolAttempts: toolAttempts,
                extra: extra,
              );
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
    final response = await _sendNonStreamingRequest(
      'POST',
      Uri.parse('$baseUrl/v1/embeddings'),
      body: body,
    );
    switch (response.statusCode) {
      case 200: // HttpStatus.ok
        return ChatGPTEmbeddingsResponse.fromJson(
          json.decode(response.body),
        ).toLLMEmbedding;
      default:
        print('\nError generating embedding: ${response.statusCode}');
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
}
