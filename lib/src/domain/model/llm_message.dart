class LLMMessage {
  LLMMessage({
    required this.role,
    this.content,
    this.toolCallId,
    this.toolCalls,
    this.images,
    this.status,
  });
  final String? content;
  final LLMRole role;

  /// ChatGPT uses toolCallId's
  final String? toolCallId;

  /// Base64 images or url
  final List<String>? images;
  final List<Map<String, dynamic>>? toolCalls;

  /// Status is used in application to inform user about what is happening
  final String? status;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'role': role.name};
    switch (role) {
      case LLMRole.user:
        final content = <Map<String, dynamic>>[];
        if (this.content != null) {
          content.add({'type': 'text', 'text': this.content});
        }
        for (final img in images ?? <String>[]) {
          content.add({
            'type': 'image_url',
            'image_url': {'url': 'data:image/png;base64,$img'},
          });
        }
        json['content'] = content;
        break;
      default:
        json['content'] = content;
        break;
    }
    if (toolCallId != null) json['tool_call_id'] = toolCallId;
    if (toolCalls != null) json['tool_calls'] = toolCalls;
    return json;
  }
}

enum LLMRole {
  /// Messages from the user
  user,

  /// System prompt for LLM
  system,

  /// Message the LLM has sent
  assistant,

  /// Resul from tool
  tool,
}
