/// Android notification channel for customer messages. The backend sends to
/// this id and the manifest uses it as the default channel.
const chatChannelId = 'chat-messages';
const chatChannelName = 'Chat messages';
const chatChannelDescription = 'A notification when a customer sends a new message.';

/// `data` of a "new message" notification (backend pushService).
class NewMessagePayload {
  const NewMessagePayload({required this.sessionId, this.agentId});

  final String sessionId;
  final String? agentId;

  static NewMessagePayload? fromData(Map<String, dynamic> data) {
    final sessionId = data['sessionId'];
    if (data['type'] != 'new_message' || sessionId is! String || sessionId.isEmpty) return null;
    final agentId = data['agentId'];
    return NewMessagePayload(sessionId: sessionId, agentId: agentId is String && agentId.isNotEmpty ? agentId : null);
  }
}
