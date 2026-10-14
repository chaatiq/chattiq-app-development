import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../theme/app_text.dart';

/// Mirrors web DashboardPageHeader: a purple title on white with a bottom border.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.breadcrumb});

  final String title;

  /// Small line above the title, like the web's "Product > Section".
  final String? breadcrumb;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (breadcrumb != null) ...[Text(breadcrumb!, style: AppText.caption), const SizedBox(height: AppSpacing.s1)],
          Semantics(
            header: true,
            child: Text(title, style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
