import 'package:flutter/material.dart';

import '../../../core/dates.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_layout.dart';
import '../../../theme/app_text.dart';
import '../chat_helpers.dart';
import '../chat_models.dart';
import 'chat_avatar.dart';

/// One chat in the list, laid out like the web inbox history item.
class InboxRow extends StatelessWidget {
  const InboxRow({super.key, required this.session, required this.onTap});

  final ChatSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = chatDisplayTitle(session);
    final phoneLine = chatContactSubtitle(session);
    final status = statusLabel(session);
    final preview = _firstNonEmpty(session.lastMessagePreview, session.summary) ?? 'Tap to open';
    final metaStyle = AppText.caption.copyWith(fontSize: 11, color: AppColors.textFaint);

    return Semantics(
      button: true,
      label: '$title. $preview',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: onTap,
          highlightColor: AppColors.rowSelected,
          splashColor: AppColors.rowSelected,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChatAvatar(session: session),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.subheading.copyWith(fontSize: 15, color: AppColors.bubbleText),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s2),
                          Text(
                            formatChatListTime(session.lastActivityAt ?? session.startedAt),
                            style: AppText.caption.copyWith(fontSize: 11.5, color: AppColors.textFaint),
                          ),
                        ],
                      ),
                      if (phoneLine.isNotEmpty)
                        Text(
                          phoneLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(fontSize: 13, height: 18 / 13, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: AppSpacing.s2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            status.text,
                            style: metaStyle.copyWith(
                              fontWeight: FontWeight.w700,
                              color: status.tone == StatusTone.active ? AppColors.statusActive : AppColors.statusDone,
                            ),
                          ),
                          if (isHumanTakeover(session))
                            Text('Human', style: metaStyle.copyWith(color: AppColors.humanPillText)),
                          if (session.agentName != null) Text(session.agentName!, style: metaStyle),
                          Text('${session.messageCount} msgs', style: metaStyle),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String? _firstNonEmpty(String? a, String? b) {
    final first = a?.trim() ?? '';
    if (first.isNotEmpty) return first;
    final second = b?.trim() ?? '';
    return second.isNotEmpty ? second : null;
  }
}
