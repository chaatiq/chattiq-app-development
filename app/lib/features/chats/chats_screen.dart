import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_router.dart';
import '../../core/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_button.dart';
import '../../widgets/form_alert.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/top_bar.dart';
import 'chat_helpers.dart';
import 'inbox_controller.dart';
import 'widgets/inbox_row.dart';

/// WhatsApp-like inbox of every agent's chats, mirroring the web "Chats" list.
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  final _search = TextEditingController();
  StatusFilter _status = StatusFilter.all;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() => ref.read(inboxControllerProvider.notifier).refresh(showSpinner: true);

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxControllerProvider);
    final chats = filterAndSortChats(inbox.chats ?? const [], search: _search.text, status: _status);
    final query = _search.text.trim();
    final emptyText = inbox.loadingFirstTime
        ? 'Loading chats…'
        : query.isNotEmpty
        ? 'No chats match “$query”'
        : 'No chats yet.';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const TopBar(),
            const ScreenHeader(title: 'Chats'),
            _Tools(search: _search, status: _status, onStatus: (value) => setState(() => _status = value)),
            if (inbox.error != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FormAlert(message: userFacingMessage(inbox.error!)),
                    const SizedBox(height: AppSpacing.s3),
                    AppButton(
                      title: 'Try again',
                      variant: AppButtonVariant.outline,
                      shape: AppButtonShape.pill,
                      onPressed: _refresh,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: chats.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          // The error box above already explains an empty list.
                          if (inbox.error == null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10, horizontal: AppSpacing.s4),
                              child: Column(
                                children: [
                                  if (inbox.loadingFirstTime)
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                                    )
                                  else
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primarySoft,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        query.isNotEmpty ? LucideIcons.searchX : LucideIcons.messageSquare,
                                        size: 24,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  const SizedBox(height: AppSpacing.s3),
                                  Text(emptyText, textAlign: TextAlign.center, style: AppText.bodyMuted),
                                ],
                              ),
                            ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final session = chats[index];
                          return InboxRow(
                            key: ValueKey(session.sessionId),
                            session: session,
                            onTap: () => context.push(Routes.chat(session.sessionId)),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools({required this.search, required this.status, required this.onStatus});

  final TextEditingController search;
  final StatusFilter status;
  final ValueChanged<StatusFilter> onStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: search,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            style: AppText.body,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search…',
              hintStyle: AppText.body.copyWith(color: AppColors.textFaint),
              prefixIcon: const Icon(LucideIcons.search, size: 16, color: AppColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: const BorderSide(color: AppColors.borderStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: const BorderSide(color: AppColors.borderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Semantics(
            label: 'Filter by status',
            child: Wrap(
              spacing: AppSpacing.s2,
              children: [
                for (final option in StatusFilter.values)
                  _FilterChip(
                    key: ValueKey('filter-${option.name}'),
                    option: option,
                    selected: option == status,
                    onTap: onStatus,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({super.key, required this.option, required this.selected, required this.onTap});

  final StatusFilter option;
  final bool selected;
  final ValueChanged<StatusFilter> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primarySoft : AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onTap(option),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: 9),
            child: Text(
              option.label,
              style: (selected ? AppText.subheading : AppText.body).copyWith(
                color: selected ? AppColors.primary : AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
