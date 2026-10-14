/// Response shapes of the chat endpoints (web inbox uses the same ones).
/// Only fields the app reads are parsed; the server may send more.
library;

String? _str(Object? value) {
  if (value == null) return null;
  final text = '$value';
  return text.isEmpty ? null : text;
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

bool _bool(Object? value) => value == true || value == 'true' || value == 1;

class ChatContact {
  const ChatContact({this.name, this.phone, this.email});

  final String? name;
  final String? phone;
  final String? email;

  factory ChatContact.fromJson(Object? json) {
    if (json is! Map) return const ChatContact();
    return ChatContact(name: _str(json['name']), phone: _str(json['phone']), email: _str(json['email']));
  }
}

/// One chat in the inbox (GET /dashboard/sessions).
class ChatSession {
  const ChatSession({
    required this.sessionId,
    this.agentId,
    this.agentName,
    this.channel,
    this.channelLabel,
    this.status,
    this.completionReason,
    this.completedAt,
    this.startedAt,
    this.lastActivityAt,
    this.lastMessagePreview,
    this.lastInboundMessageId,
    this.messageCount = 0,
    this.summary,
    this.humanTakeover = false,
    this.aiPaused = false,
    this.contact = const ChatContact(),
  });

  final String sessionId;
  final String? agentId;
  final String? agentName;
  final String? channel;
  final String? channelLabel;
  final String? status;
  final String? completionReason;
  final String? completedAt;
  final String? startedAt;
  final String? lastActivityAt;
  final String? lastMessagePreview;
  final String? lastInboundMessageId;
  final int messageCount;
  final String? summary;

  /// A person replies instead of the AI (WhatsApp only).
  final bool humanTakeover;
  final bool aiPaused;
  final ChatContact contact;

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    sessionId: '${json['session_id'] ?? ''}',
    agentId: _str(json['agent_id']),
    agentName: _str(json['agent_name']),
    channel: _str(json['channel']),
    channelLabel: _str(json['channel_label']),
    status: _str(json['status']),
    completionReason: _str(json['completion_reason']),
    completedAt: _str(json['completed_at']),
    startedAt: _str(json['started_at']),
    lastActivityAt: _str(json['last_activity_at']),
    lastMessagePreview: _str(json['last_message_preview']),
    lastInboundMessageId: _str(json['last_inbound_message_id']),
    messageCount: _int(json['message_count']),
    summary: _str(json['summary']),
    humanTakeover: _bool(json['human_takeover']),
    aiPaused: _bool(json['ai_paused']),
    contact: ChatContact.fromJson(json['contact']),
  );
}

class ChatMessage {
  const ChatMessage({this.role, this.content, this.timestamp});

  final String? role;
  final String? content;
  final String? timestamp;

  factory ChatMessage.fromJson(Object? json) {
    if (json is! Map) return const ChatMessage();
    return ChatMessage(role: _str(json['role']), content: _str(json['content']), timestamp: _str(json['timestamp']));
  }
}
