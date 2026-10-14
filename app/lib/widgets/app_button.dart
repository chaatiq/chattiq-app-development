import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../theme/app_text.dart';

enum AppButtonVariant { primary, outline }

enum AppButtonShape { auth, pill }

/// `primary` = web auth.css submit (black), `outline` = white with a grey border.
/// `auth` uses the auth pages' 10px corners, `pill` the dashboard's rounded-[2rem].
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.loadingTitle,
    this.loading = false,
    this.variant = AppButtonVariant.primary,
    this.shape = AppButtonShape.auth,
  });

  final String title;

  /// Text shown while [loading], e.g. "Logging in…".
  final String? loadingTitle;
  final bool loading;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonShape shape;

  @override
  Widget build(BuildContext context) {
    final primary = variant == AppButtonVariant.primary;
    final foreground = primary ? AppColors.textOnDark : AppColors.textStrong;
    final radius = BorderRadius.circular(shape == AppButtonShape.auth ? AppRadius.auth : AppRadius.button);
    final disabled = loading || onPressed == null;

    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: Material(
        color: primary ? AppColors.buttonPrimary : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: primary ? BorderSide.none : const BorderSide(color: AppColors.border, width: 1.5),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: disabled ? null : onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: hitTarget + 6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (loading) ...[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                  ],
                  Text(
                    loading && loadingTitle != null ? loadingTitle! : title,
                    style: AppText.button.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
