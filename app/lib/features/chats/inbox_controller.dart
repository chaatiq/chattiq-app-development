import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'chat_helpers.dart';
import 'chat_models.dart';
import 'chats_api.dart';

final chatsApiProvider = Provider<ChatsApi>((ref) => ChatsApi(ref.watch(apiClientProvider)));

/// The web refreshes the chat list every 15 seconds.
const inboxPollInterval = Duration(seconds: 15);

class InboxState {
  const InboxState({this.chats, this.error, this.refreshing = false});

  /// Null until the first load finishes.
  final List<ChatSession>? chats;

  /// Last load error; the previous list stays visible.
  final Object? error;
  final bool refreshing;

  bool get loadingFirstTime => chats == null && error == null;
}

final inboxControllerProvider = NotifierProvider<InboxController, InboxState>(InboxController.new);

/// Loads the inbox, keeps it fresh while the app is open, and stops when the
/// app is in the background or the user signs out.
class InboxController extends Notifier<InboxState> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _loading = false;

  @override
  InboxState build() {
    final signedIn = ref.watch(authControllerProvider.select((auth) => auth.status == AuthStatus.signedIn));
    ref.onDispose(_stop);
    if (!signedIn) return const InboxState();

    _lifecycle = AppLifecycleListener(
      onResume: () {
        unawaited(refresh());
        _startTimer();
      },
      onPause: _cancelTimer,
    );
    _startTimer();
    unawaited(Future.microtask(refresh));
    return const InboxState();
  }

  void _startTimer() {
    _cancelTimer();
    _timer = Timer.periodic(inboxPollInterval, (_) => unawaited(refresh()));
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _stop() {
    _cancelTimer();
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  /// Reloads the list; a failure keeps the last list and records the error.
  Future<void> refresh({bool showSpinner = false}) async {
    if (_loading) return;
    _loading = true;
    if (showSpinner) state = InboxState(chats: state.chats, error: state.error, refreshing: true);
    try {
      final chats = await ref.read(chatsApiProvider).fetchInbox();
      if (!ref.mounted) return;
      // The app is for WhatsApp agents only; website chatbot chats stay on the web dashboard.
      state = InboxState(chats: chats.where(isWhatsAppSession).toList());
    } catch (error) {
      if (!ref.mounted) return;
      state = InboxState(chats: state.chats, error: error);
    } finally {
      _loading = false;
    }
  }
}
