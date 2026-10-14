import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_exception.dart';
import '../../core/dates.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_text.dart';
import '../chats/chat_helpers.dart';
import '../chats/chat_models.dart';
import '../chats/chats_api.dart';
import '../chats/inbox_controller.dart';
import '../chats/widgets/chat_avatar.dart';
import 'conversation_controller.dart';
import 'widgets/message_bubble.dart';

/// The web sends the WhatsApp "typing…" signal at most every 16 seconds.
const _typingRefresh = Duration(seconds: 16);

/// One conversation, mirroring the web inbox ConversationPanel.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _draft = TextEditingController();
  Timer? _clock;
  DateTime _now = DateTime.now();
  bool _busy = false;

  /// `_busy` updates after a rebuild; this blocks a fast double tap at once.
  bool _inFlight = false;
  String _error = '';
  bool _confirmCharge = false;
  String _lastReadId = '';
  DateTime _lastTypingAt = DateTime.fromMillisecondsSinceEpoch(0);

  String get _sessionId => widget.sessionId;
  ChatsApi get _api => ref.read(chatsApiProvider);
  ConversationController get _controller => ref.read(conversationProvider(_sessionId).notifier);

  @override
  void initState() {
    super.initState();
    _draft.addListener(() => setState(() {}));
    // Keep the 24-hour countdown current, like the web (every 30 s).
    _clock = Timer.periodic(const Duration(seconds: 30), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _clock?.cancel();
    _draft.dispose();
    super.dispose();
  }

  /// Read receipts when the chat opens and whenever a new customer message arrives.
  void _maybeMarkRead(ChatSession? session) {
    if (session == null) return;
    final inboundId = session.lastInboundMessageId ?? session.sessionId;
    if (inboundId == _lastReadId) return;
    _lastReadId = inboundId;
    unawaited(_api.markRead(session.sessionId));
  }

  Future<void> _run(Future<void> Function() action, String fallback) async {
    if (_inFlight) return;
    _inFlight = true;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await action();
      await _controller.refreshAll();
    } catch (error) {
      if (mounted) setState(() => _error = error is ApiException ? error.message : fallback);
    } finally {
      _inFlight = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleTakeover(ChatSession session) => _run(() async {
    final takeover = isHumanTakeover(session);
    await _api.setTakeover(_sessionId, active: !takeover, agentId: session.agentId);
    if (!takeover) unawaited(_api.markRead(_sessionId));
  }, 'Could not update agent status');

  Future<void> _reopen() => _run(() => _api.reopen(_sessionId), 'Could not reopen chat');

  Future<void> _send({required bool confirmCharge}) async {
    final text = _draft.text.trim();
    if (text.isEmpty || _inFlight) return;
    _inFlight = true;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final result = await _api.sendHumanReply(_sessionId, text, confirmCharge: confirmCharge);
      if (!mounted) return;
      switch (result) {
        case ReplyNeedsChargeConfirm():
          setState(() => _confirmCharge = true);
        case ReplySent(:final message):
          _draft.clear();
          setState(() => _confirmCharge = false);
          _controller.appendSentReply(message ?? text);
          await _controller.refreshAll();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = userFacingMessage(error);
          _confirmCharge = false;
        });
      }
    } finally {
      _inFlight = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit(ServiceWindow window) {
    // Outside the free window, confirm the Meta charge first (web does the same).
    if (!window.open) {
      setState(() => _confirmCharge = true);
      return;
    }
    unawaited(_send(confirmCharge: false));
  }

  void _onDraftChanged(String value, bool canReply) {
    final now = DateTime.now();
    if (canReply && value.trim().isNotEmpty && now.difference(_lastTypingAt) > _typingRefresh) {
      _lastTypingAt = now;
      unawaited(_api.sendTyping(_sessionId));
    }
  }

  void _goBack() => context.canPop() ? context.pop() : context.go('/');

  @override
  Widget build(BuildContext context) {
    ref.listen(conversationProvider(_sessionId), (_, next) => _maybeMarkRead(next.session));
    final conversation = ref.watch(conversationProvider(_sessionId));
    final inboxMatch = (ref.watch(inboxControllerProvider).chats ?? const <ChatSession>[]).where(
      (chat) => chat.sessionId == _sessionId,
    );
    // Header shows straight away from the inbox, then from the loaded chat.
    final session = conversation.session ?? (inboxMatch.isEmpty ? null : inboxMatch.first);

    final messages = visibleMessages(conversation.messages);
    final whatsapp = session != null ? isWhatsAppSession(session) : _sessionId.startsWith('whatsapp_');
    final takeover = session != null && isHumanTakeover(session);
    final completed = session != null && isCompleted(session);
    final window = serviceWindowFromMessages(messages, now: _now);
    final canReply = whatsapp && takeover && !completed;

    return Scaffold(
      backgroundColor: AppColors.chatBar,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              session: session,
              takeover: takeover,
              showTakeoverButton: whatsapp && session != null && !completed,
              busy: _busy,
              onBack: _goBack,
              onToggleTakeover: session == null ? null : () => _toggleTakeover(session),
            ),
            if (whatsapp && session != null) _WindowStrip(window: window),
            if (completed) _CompletedBanner(session: session),
            Expanded(
              child: ColoredBox(
                color: AppColors.chatWallpaper,
                child: _Thread(
                  loading: conversation.detail == null && conversation.error == null,
                  error: conversation.detail == null ? conversation.error : null,
                  messages: messages,
                  userInitials: session == null ? null : avatarInitials(session),
                ),
              ),
            ),
            _Composer(
              draft: _draft,
              whatsapp: whatsapp,
              takeover: takeover,
              completed: completed,
              canReply: canReply,
              busy: _busy,
              error: _error,
              confirmCharge: _confirmCharge,
              onChanged: (value) => _onDraftChanged(value, canReply),
              onSend: () => _submit(window),
              onConfirmCharge: () => _send(confirmCharge: true),
              onCancelCharge: () => setState(() => _confirmCharge = false),
              onReopen: _reopen,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.takeover,
    required this.showTakeoverButton,
    required this.busy,
    required this.onBack,
    required this.onToggleTakeover,
  });

  final ChatSession? session;
  final bool takeover;
  final bool showTakeoverButton;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback? onToggleTakeover;

  @override
  Widget build(BuildContext context) {
    final session = this.session;
    final subtitle = session == null
        ? ''
        : [
            chatContactSubtitle(session),
            session.agentName,
            session.channelLabel,
          ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');

    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.only(left: AppSpacing.s1, right: AppSpacing.s3),
      decoration: const BoxDecoration(
        color: AppColors.chatBar,
        border: Border(bottom: BorderSide(color: AppColors.chatBarBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to chats',
            onPressed: onBack,
            icon: const Icon(LucideIcons.arrowLeft, color: AppColors.text, size: 22),
          ),
          if (session != null) ...[ChatAvatar(session: session, size: 38), const SizedBox(width: AppSpacing.s2)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session == null ? 'Chat' : chatDisplayTitle(session),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subheading.copyWith(fontSize: 16, color: AppColors.bubbleText),
                ),
                if (session != null) ...[
                  const SizedBox(height: 2),
                  // Status pill sits under the name so a long name is not squeezed by the button.
                  Row(
                    children: [
                      _Pill(takeover: takeover),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (showTakeoverButton) ...[
            const SizedBox(width: AppSpacing.s2),
            _TakeoverButton(takeover: takeover, busy: busy, onPressed: onToggleTakeover),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.takeover});

  final bool takeover;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: takeover ? AppColors.humanPillBg : AppColors.aiPillBg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        takeover ? 'Human' : 'AI',
        style: AppText.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: takeover ? AppColors.humanPillText : AppColors.aiPillText,
        ),
      ),
    );
  }
}

class _TakeoverButton extends StatelessWidget {
  const _TakeoverButton({required this.takeover, required this.busy, required this.onPressed});

  final bool takeover;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.6 : 1,
      child: Material(
        color: takeover ? AppColors.resumeBg : AppColors.takeoverBg,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.text)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: busy ? null : onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: 6),
              child: Text(
                takeover ? 'Resume AI' : 'Stop AI & chat',
                maxLines: 1,
                style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowStrip extends StatelessWidget {
  const _WindowStrip({required this.window});

  final ServiceWindow window;

  @override
  Widget build(BuildContext context) {
    final color = window.open ? AppColors.windowOpenText : AppColors.windowClosedText;
    final style = AppText.caption.copyWith(color: color);
    final countdown = formatWindowCountdown(window.secondsRemaining);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: 6),
      color: window.open ? AppColors.windowOpenBg : AppColors.windowClosedBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            window.open ? '24h window open' : '24h window closed',
            style: style.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            window.open
                ? (countdown.isNotEmpty ? countdown : 'Customer messaged recently — free Meta messaging')
                : 'Replies are charged by Meta until the customer messages again.',
            style: style,
          ),
        ],
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner({required this.session});

  final ChatSession session;

  @override
  Widget build(BuildContext context) {
    final reason = completionReasonText(session.completionReason);
    final when = session.completedAt == null
        ? ''
        : ' · ${formatShortDate(session.completedAt)} ${formatTime(session.completedAt)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
      decoration: const BoxDecoration(
        color: AppColors.borderSubtle,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Text(
        'Conversation marked complete${reason.isNotEmpty ? ' · $reason' : ''}$when',
        style: AppText.caption.copyWith(fontSize: 12.5, color: AppColors.textSecondary),
      ),
    );
  }
}

class _Thread extends StatelessWidget {
  const _Thread({required this.loading, required this.error, required this.messages, required this.userInitials});

  final bool loading;
  final Object? error;
  final List<ChatMessage> messages;
  final String? userInitials;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.s2),
            Text('Loading conversation…', style: AppText.bodyMuted),
          ],
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Text(userFacingMessage(error!), textAlign: TextAlign.center, style: AppText.bodyMuted),
        ),
      );
    }
    if (messages.isEmpty) {
      return Center(child: Text('No messages in this thread yet.', style: AppText.bodyMuted));
    }

    // Reversed list: newest at the bottom and the thread opens at the latest message, like WhatsApp.
    final timeline = buildTimeline(messages).reversed.toList();
    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: timeline.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) => switch (timeline[index]) {
        DateItem(:final key, :final label) => DateChip(key: ValueKey(key), label: label),
        MessageItem(:final key, :final message) => MessageBubble(
          key: ValueKey(key),
          message: message,
          userInitials: userInitials,
        ),
      },
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.draft,
    required this.whatsapp,
    required this.takeover,
    required this.completed,
    required this.canReply,
    required this.busy,
    required this.error,
    required this.confirmCharge,
    required this.onChanged,
    required this.onSend,
    required this.onConfirmCharge,
    required this.onCancelCharge,
    required this.onReopen,
  });

  final TextEditingController draft;
  final bool whatsapp;
  final bool takeover;
  final bool completed;
  final bool canReply;
  final bool busy;
  final String error;
  final bool confirmCharge;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onConfirmCharge;
  final VoidCallback onCancelCharge;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final hintStyle = AppText.caption.copyWith(fontSize: 11.5, color: AppColors.textMuted);
    final sendEnabled = canReply && !busy && draft.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s3, AppSpacing.s2, AppSpacing.s3, AppSpacing.s2),
      decoration: const BoxDecoration(
        color: AppColors.chatBar,
        border: Border(top: BorderSide(color: AppColors.chatBarBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (confirmCharge) ...[
            _ChargeConfirm(busy: busy, onConfirm: onConfirmCharge, onCancel: onCancelCharge),
            const SizedBox(height: 6),
          ],
          if (error.isNotEmpty) ...[
            Semantics(
              liveRegion: true,
              child: Text(error, style: AppText.body.copyWith(fontSize: 13, color: AppColors.danger)),
            ),
            const SizedBox(height: 6),
          ],
          if (completed) ...[
            Text(
              'This chat is completed. Reopen it to continue the conversation.',
              textAlign: TextAlign.center,
              style: hintStyle,
            ),
            const SizedBox(height: AppSpacing.s2),
            Center(
              child: _ReopenButton(busy: busy, onPressed: onReopen),
            ),
          ] else if (!whatsapp) ...[
            // Website / Telegram chats are read-only here, so no dead reply box.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.info, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Replies are available for WhatsApp chats only',
                      style: AppText.body.copyWith(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: draft,
                    enabled: canReply && !busy,
                    minLines: 1,
                    maxLines: 5,
                    onChanged: onChanged,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppText.body.copyWith(fontSize: 15, color: AppColors.bubbleText),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surface,
                      hintText: takeover ? 'Type a message…' : 'Stop AI & chat to reply as human…',
                      hintStyle: AppText.body.copyWith(fontSize: 15, color: AppColors.textFaint),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Opacity(
                  opacity: sendEnabled ? 1 : 0.45,
                  child: Material(
                    color: AppColors.whatsapp,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: sendEnabled ? onSend : null,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnDark),
                                )
                              : const Icon(
                                  LucideIcons.sendHorizontal,
                                  size: 20,
                                  color: AppColors.textOnDark,
                                  semanticLabel: 'Send',
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              takeover ? 'You are chatting as a human · powered by Chattiq' : 'AI is answering · stop AI to take over',
              textAlign: TextAlign.center,
              style: hintStyle,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChargeConfirm extends StatelessWidget {
  const _ChargeConfirm({required this.busy, required this.onConfirm, required this.onCancel});

  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  Widget _button(String label, Color color, VoidCallback onTap) => Material(
    color: color,
    shape: const StadiumBorder(side: BorderSide(color: AppColors.text)),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: 10),
        child: Text(label, style: AppText.subheading),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(color: AppColors.windowClosedBg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'The free 24-hour window is closed. Sending now may be charged by Meta. Continue?',
              style: AppText.body,
            ),
            const SizedBox(height: AppSpacing.s3),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _button('Cancel', AppColors.surface, onCancel),
                const SizedBox(width: AppSpacing.s2),
                _button('Send anyway', AppColors.chargeConfirm, onConfirm),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReopenButton extends StatelessWidget {
  const _ReopenButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.6 : 1,
      child: Material(
        color: AppColors.takeoverBg,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.text)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: busy ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5, vertical: 8),
            child: Text(
              'Reopen',
              style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.text),
            ),
          ),
        ),
      ),
    );
  }
}
