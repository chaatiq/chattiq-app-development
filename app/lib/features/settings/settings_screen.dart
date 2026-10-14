import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_button.dart';
import '../../widgets/form_alert.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/top_bar.dart';
import '../auth/auth_controller.dart';
import '../notifications/push_controller.dart';
import '../notifications/push_platform.dart';
import 'notification_settings.dart';

/// Message notifications on/off and the account. No AI agent settings are reachable from the app.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    await ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const TopBar(),
            const ScreenHeader(title: 'Settings'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.s4),
                children: [
                  const _NotificationsCard(),
                  const SizedBox(height: AppSpacing.s4),
                  _Card(
                    children: [
                      Text('ACCOUNT', style: AppText.overline),
                      const SizedBox(height: AppSpacing.s2),
                      Text(user?.displayName ?? 'Signed in', style: AppText.heading),
                      if (user != null && user.userName.isNotEmpty) Text(user.email, style: AppText.bodyMuted),
                      const SizedBox(height: AppSpacing.s4),
                      AppButton(
                        title: 'Log out',
                        loadingTitle: 'Logging out…',
                        loading: _signingOut,
                        variant: AppButtonVariant.outline,
                        shape: AppButtonShape.pill,
                        onPressed: _signOut,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  const _AppVersion(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final controller = ref.read(notificationSettingsProvider.notifier);
    final disabled = settings.loading || settings.enabled == null;

    return _Card(
      children: [
        Text('NOTIFICATIONS', style: AppText.overline),
        const SizedBox(height: AppSpacing.s2),
        Semantics(header: true, child: Text('Message notifications', style: AppText.heading)),
        const SizedBox(height: 2),
        Text('Get a notification on this phone when a customer sends a new message.', style: AppText.bodyMuted),
        const SizedBox(height: AppSpacing.s3),
        Semantics(
          label: 'Message notifications',
          child: Row(
            children: [
              Expanded(
                child: _RadioOption(
                  key: const ValueKey('notifications-on'),
                  label: 'On',
                  selected: settings.enabled == true,
                  disabled: disabled,
                  onSelect: () => controller.setEnabled(true),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: _RadioOption(
                  key: const ValueKey('notifications-off'),
                  label: 'Off',
                  selected: settings.enabled == false,
                  disabled: disabled,
                  onSelect: () => controller.setEnabled(false),
                ),
              ),
            ],
          ),
        ),
        if (settings.loadError != null) ...[
          const SizedBox(height: AppSpacing.s3),
          FormAlert(message: userFacingMessage(settings.loadError!)),
          const SizedBox(height: AppSpacing.s3),
          AppButton(
            title: 'Try again',
            variant: AppButtonVariant.outline,
            shape: AppButtonShape.pill,
            onPressed: controller.load,
          ),
        ],
        if (settings.saveError != null) ...[
          const SizedBox(height: AppSpacing.s3),
          FormAlert(message: userFacingMessage(settings.saveError!)),
        ],
        if (settings.enabled == true) const _PhoneStatus(),
      ],
    );
  }
}

/// Explains why this phone may not show notifications even though they are on.
class _PhoneStatus extends ConsumerWidget {
  const _PhoneStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(pushControllerProvider.select((push) => push.permission));
    switch (permission) {
      case PushPermission.granted:
        return const SizedBox.shrink();
      case PushPermission.unavailable:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s3),
          child: Text('Notifications are not set up in this build of the app.', style: AppText.caption),
        );
      case PushPermission.denied:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FormAlert(message: 'Notifications are turned off for Chattiq in your phone settings.'),
              const SizedBox(height: AppSpacing.s3),
              AppButton(
                title: 'Open phone settings',
                variant: AppButtonVariant.outline,
                shape: AppButtonShape.pill,
                onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.notification),
              ),
            ],
          ),
        );
      case PushPermission.notDetermined:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Allow notifications so new messages can reach this phone.', style: AppText.bodyMuted),
              const SizedBox(height: AppSpacing.s3),
              AppButton(
                title: 'Allow notifications',
                shape: AppButtonShape.pill,
                onPressed: () => ref.read(pushControllerProvider.notifier).requestPermission(),
              ),
            ],
          ),
        );
    }
  }
}

/// A radio choice drawn as a bordered tile, like the web radio cards.
class _RadioOption extends StatelessWidget {
  const _RadioOption({
    super.key,
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onSelect,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: !disabled,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: disabled ? 0.6 : 1,
        child: Material(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: disabled || selected ? null : onSelect,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? AppColors.primary : AppColors.borderStrong, width: 2),
                    ),
                    child: selected
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Text(label, style: AppText.heading.copyWith(color: selected ? AppColors.primary : AppColors.text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Read once; top-level finals are lazy, so this runs the first time Settings opens.
final _packageInfo = PackageInfo.fromPlatform();

/// "Chattiq v1.0.0" under the cards, handy when a user reports a problem.
/// (No "(build)" suffix: Product Sans draws "(1)" like an info icon.)
class _AppVersion extends StatelessWidget {
  const _AppVersion();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _packageInfo,
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox.shrink();
        return Text(
          'Chattiq v${info.version}',
          textAlign: TextAlign.center,
          style: AppText.caption.copyWith(color: AppColors.textFaint),
        );
      },
    );
  }
}

/// Mirrors the web dashboard cards: white, rounded-[2rem], light border.
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
