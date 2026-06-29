class ChatMessage {
  final String role;
  final String content;

  ChatMessage({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
    );
  }
}

class ChatStreamEvent {
  final String? type;
  final String? status;
  final String? reasoning;
  final String? content;
  final String? text;
  final String? delta;
  final bool? done;
  final String? tool;
  final Map<String, dynamic>? args;
  final int? iteration;
  final String? error;

  ChatStreamEvent({
    this.type,
    this.status,
    this.reasoning,
    this.content,
    this.text,
    this.delta,
    this.done,
    this.tool,
    this.args,
    this.iteration,
    this.error,
  });

  factory ChatStreamEvent.fromJson(Map<String, dynamic> json) {
    return ChatStreamEvent(
      type: json['type'] as String?,
      status: json['status'] as String?,
      reasoning: json['reasoning'] as String?,
      content: json['content'] as String?,
      text: json['text'] as String?,
      delta: json['delta'] as String?,
      done: json['done'] as bool?,
      tool: json['tool'] as String?,
      args: json['args'] as Map<String, dynamic>?,
      iteration: json['iteration'] as int?,
      error: json['error'] as String?,
    );
  }
}
