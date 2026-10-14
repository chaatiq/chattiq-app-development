import 'package:flutter/material.dart';

import '../../../core/dates.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_layout.dart';
import '../../../theme/app_text.dart';
import '../../chats/chat_helpers.dart';
import '../../chats/chat_models.dart';

final _bulletLine = RegExp(r'^\s*[-*]\s+', multiLine: true);
final _boldSpan = RegExp(r'(\*\*[^*\n]+\*\*|\*[^*\n]+\*)');

/// Light formatting like the web bubbles: **bold** and WhatsApp *bold*, kept
/// line breaks, and "- " / "• " bullets. Everything else stays plain text.
List<TextSpan> formatMessageSpans(String content, TextStyle base) {
  final text = content.replaceAll('\r\n', '\n').replaceAll(_bulletLine, '• ');
  final spans = <TextSpan>[];
  var start = 0;
  for (final match in _boldSpan.allMatches(text)) {
    if (match.start > start) spans.add(TextSpan(text: text.substring(start, match.start)));
    final token = match.group(0)!;
    final inner = token.startsWith('**') ? token.substring(2, token.length - 2) : token.substring(1, token.length - 1);
    spans.add(
      TextSpan(
        text: inner,
        style: base.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    start = match.end;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return spans;
}

/// WhatsApp-style bubble: customer on the right in green, AI / owner on the left in white.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, this.userInitials});

  final ChatMessage message;

  /// Customer initials for the avatar beside their messages (web: avatarInitials(session)).
  final String? userInitials;

  @override
  Widget build(BuildContext context) {
    final user = isUserMessage(message.role);
    final time = formatTime(message.timestamp);
    final textStyle = AppText.body.copyWith(fontSize: 14.5, height: 21 / 14.5, color: AppColors.bubbleText);
    const corner = Radius.circular(12);

    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s3, AppSpacing.s2, AppSpacing.s3, 6),
      decoration: BoxDecoration(
        color: user ? AppColors.bubbleUser : AppColors.bubbleAi,
        borderRadius: user
            ? const BorderRadius.only(topLeft: corner, bottomLeft: corner, bottomRight: corner)
            : const BorderRadius.only(topRight: corner, bottomLeft: corner, bottomRight: corner),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 1, offset: Offset(0, 1))],
      ),
      child: Column(
        // Bubble hugs the text, so short messages stay short (Align here would stretch it).
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText.rich(
            TextSpan(style: textStyle, children: formatMessageSpans(message.content ?? '', textStyle)),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              time,
              style: AppText.caption.copyWith(
                fontSize: 10.5,
                color: user ? AppColors.bubbleUserTime : AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
    final showUserAvatar = user && (userInitials?.isNotEmpty ?? false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!user) ...[const _BotAvatar(), const SizedBox(width: 6)],
            // Bubbles take at most 80% of the row, like the web.
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.8),
                child: bubble,
              ),
            ),
            if (showUserAvatar) ...[const SizedBox(width: 6), _UserAvatar(initials: userInitials!)],
          ],
        ),
      ),
    );
  }
}

/// Same as web .cdb-inbox-bot-avatar: white circle, soft shadow, 24px logo inside.
class _BotAvatar extends StatelessWidget {
  const _BotAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Image.asset(
        'assets/images/bot-avatar.png',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Same as web .cdb-inbox-user-avatar.
class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle),
        child: Text(
          initials,
          style: AppText.subheading.copyWith(fontSize: 10.5, color: AppColors.textOnDark, height: 1),
        ),
      ),
    );
  }
}

/// Date chip between messages ("Today", "Yesterday", "Mon, 5 Oct 2026").
class DateChip extends StatelessWidget {
  const DateChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: 4),
          decoration: BoxDecoration(color: AppColors.dateChipBg, borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: AppText.caption.copyWith(color: AppColors.dateChipText)),
        ),
      ),
    );
  }
}
