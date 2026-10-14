import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';

/// Mirrors web DashboardTopBar: the Chattiq logo on a white bar with a bottom border.
class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      alignment: Alignment.centerLeft,
      // Same left edge as the page title and list below.
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Image.asset('assets/images/logo.png', width: 100, semanticLabel: 'Chattiq'),
    );
  }
}
