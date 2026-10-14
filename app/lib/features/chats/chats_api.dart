import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import 'chat_models.dart';

/// GET /dashboard/sessions/:id
class ChatDetail {
  const ChatDetail({this.session, this.messages = const []});

  final ChatSession? session;
  final List<ChatMessage> messages;
}

/// Result of sending a reply: sent, or the Meta charge must be confirmed first.
sealed class ReplyResult {
  const ReplyResult();
}

class ReplySent extends ReplyResult {
  const ReplySent(this.message);

  /// The text as the server stored it (may differ slightly from what was typed).
  final String? message;
}

class ReplyNeedsChargeConfirm extends ReplyResult {
  const ReplyNeedsChargeConfirm();
}

/// Same endpoints and payloads as the web inbox (ChatsInbox.jsx).
class ChatsApi {
  ChatsApi(this._api);

  final ApiClient _api;

  static String _path(String sessionId, [String suffix = '']) =>
      '/dashboard/sessions/${Uri.encodeComponent(sessionId)}$suffix';

  static bool _isWhatsApp(String sessionId) => sessionId.startsWith('whatsapp_');

  /// Every chat of every agent the user owns (no agent filter, like a WhatsApp inbox).
  Future<List<ChatSession>> fetchInbox() async {
    final data = await _api.get('/dashboard/sessions', query: {'limit': 200});
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((json) => ChatSession.fromJson(Map<String, dynamic>.from(json)))
        .where((session) => session.sessionId.isNotEmpty)
        .toList();
  }

  Future<ChatDetail> fetchChat(String sessionId) async {
    final data = await _api.get(_path(sessionId));
    if (data is! Map) return const ChatDetail();
    final session = data['session'];
    final messages = data['messages'];
    return ChatDetail(
      session: session is Map ? ChatSession.fromJson(Map<String, dynamic>.from(session)) : null,
      messages: messages is List ? messages.map(ChatMessage.fromJson).toList() : const [],
    );
  }

  /// Sends WhatsApp read receipts; best effort.
  Future<void> markRead(String sessionId) async {
    if (!_isWhatsApp(sessionId)) return;
    try {
      await _api.post(_path(sessionId, '/read'));
    } catch (_) {
      // Read receipts must never block the chat.
    }
  }

  /// Shows "typing…" to the WhatsApp customer while the owner writes; best effort.
  Future<void> sendTyping(String sessionId) async {
    if (!_isWhatsApp(sessionId)) return;
    try {
      await _api.post(_path(sessionId, '/typing'));
    } catch (_) {
      // Not important enough to surface.
    }
  }

  /// "Stop AI & chat" (active = true) or "Resume AI" (active = false).
  Future<void> setTakeover(String sessionId, {required bool active, String? agentId}) =>
      _api.post(_path(sessionId, '/takeover'), body: {'active': active, 'agent_id': agentId ?? ''});

  /// Sends the owner's reply. Outside Meta's free 24-hour window the server
  /// asks for confirmation first (HTTP 402 or needs_charge_confirm).
  Future<ReplyResult> sendHumanReply(String sessionId, String message, {required bool confirmCharge}) async {
    try {
      final data = await _api.post(
        _path(sessionId, '/human-reply'),
        body: {'message': message, 'confirm_charge': confirmCharge},
      );
      if (data is Map && data['needs_charge_confirm'] == true) return const ReplyNeedsChargeConfirm();
      return ReplySent(data is Map && data['message'] is String ? data['message'] as String : null);
    } on ApiException catch (error) {
      final body = error.data;
      if (error.status == 402 || (body is Map && body['needs_charge_confirm'] == true)) {
        return const ReplyNeedsChargeConfirm();
      }
      rethrow;
    }
  }

  Future<void> reopen(String sessionId) => _api.post(_path(sessionId, '/reopen'));
}
