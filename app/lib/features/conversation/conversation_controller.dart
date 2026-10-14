import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chats/chat_models.dart';
import '../chats/chats_api.dart';
import '../chats/inbox_controller.dart';

/// The web keeps an open thread live by polling every 3 seconds.
const conversationPollInterval = Duration(seconds: 3);

class ConversationState {
  const ConversationState({this.detail, this.error});

  /// Null until the first load finishes.
  final ChatDetail? detail;

  /// Last load error; the previous messages stay visible.
  final Object? error;

  ChatSession? get session => detail?.session;
  List<ChatMessage> get messages => detail?.messages ?? const [];
}

final conversationProvider = NotifierProvider.autoDispose.family<ConversationController, ConversationState, String>(
  ConversationController.new,
);

/// One open conversation: loads it, keeps it live while visible, and stops
/// polling in the background and when the screen closes.
class ConversationController extends Notifier<ConversationState> {
  ConversationController(this.sessionId);

  final String sessionId;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _loading = false;

  ChatsApi get _api => ref.read(chatsApiProvider);

  @override
  ConversationState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
    });
    _lifecycle = AppLifecycleListener(
      onResume: () {
        unawaited(refresh());
        _startTimer();
      },
      onPause: () => _timer?.cancel(),
    );
    _startTimer();
    unawaited(Future.microtask(refresh));
    return const ConversationState();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(conversationPollInterval, (_) => unawaited(refresh()));
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final detail = await _api.fetchChat(sessionId);
      if (!ref.mounted) return;
      state = ConversationState(detail: detail);
    } catch (error) {
      if (!ref.mounted) return;
      state = ConversationState(detail: state.detail, error: error);
    } finally {
      _loading = false;
    }
  }

  /// Reloads this chat and, in the background, the inbox (status, takeover, preview).
  Future<void> refreshAll() async {
    await refresh();
    unawaited(ref.read(inboxControllerProvider.notifier).refresh());
  }

  /// Shows a sent reply at once; the next poll brings the server's copy.
  void appendSentReply(String text) {
    final detail = state.detail;
    if (detail == null) return;
    state = ConversationState(
      detail: ChatDetail(
        session: detail.session,
        messages: [
          ...detail.messages,
          ChatMessage(role: 'assistant', content: text, timestamp: DateTime.now().toUtc().toIso8601String()),
        ],
      ),
    );
  }
}
