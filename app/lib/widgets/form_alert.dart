import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../theme/app_text.dart';

/// Mirrors web auth.css `.auth-form__alert` (amber) and `.auth-form__success` (green).
class FormAlert extends StatelessWidget {
  const FormAlert({super.key, required this.message, this.success = false});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
        decoration: BoxDecoration(
          color: success ? AppColors.successBg : AppColors.warningBg,
          border: Border.all(color: success ? AppColors.successBorder : AppColors.warningBorder),
          borderRadius: BorderRadius.circular(AppRadius.auth),
        ),
        child: Text(
          message,
          style: AppText.body.copyWith(color: success ? AppColors.successText : AppColors.warningText, height: 21 / 14),
        ),
      ),
    );
  }
}
