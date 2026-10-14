import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// Two tabs only: the chat inbox and settings.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: AppColors.primarySoft,
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => AppText.tab.copyWith(
                color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.text,
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                size: 22,
                color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.text,
              ),
            ),
          ),
          child: NavigationBar(
            height: 64,
            selectedIndex: shell.currentIndex,
            // Tapping the current tab again returns it to its first screen.
            onDestinationSelected: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
            destinations: const [
              NavigationDestination(icon: Icon(LucideIcons.messageSquare), label: 'Chats'),
              NavigationDestination(icon: Icon(LucideIcons.settings), label: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }
}
