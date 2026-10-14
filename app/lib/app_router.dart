import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/auth_models.dart';
import 'features/auth/login_screen.dart';
import 'features/chats/chats_screen.dart';
import 'features/conversation/conversation_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/start/start_screen.dart';

abstract final class Routes {
  static const start = '/start';
  static const login = '/login';
  static const chats = '/';
  static const settings = '/settings';

  static String chat(String sessionId) => '/chat/${Uri.encodeComponent(sessionId)}';
}

/// Signed-out users only see the login screen; signed-in users never see it.
final routerProvider = Provider<GoRouter>((ref) {
  final authChanges = ValueNotifier<AuthStatus>(ref.read(authControllerProvider).status);
  ref.listen(authControllerProvider, (_, next) => authChanges.value = next.status);
  ref.onDispose(authChanges.dispose);

  return GoRouter(
    initialLocation: Routes.start,
    refreshListenable: authChanges,
    redirect: (context, state) {
      final location = state.matchedLocation;
      switch (authChanges.value) {
        case AuthStatus.loading:
          return location == Routes.start ? null : Routes.start;
        case AuthStatus.signedOut:
          return location == Routes.login ? null : Routes.login;
        case AuthStatus.signedIn:
          return location == Routes.start || location == Routes.login ? Routes.chats : null;
      }
    },
    routes: [
      GoRoute(path: Routes.start, builder: (context, state) => const StartScreen()),
      GoRoute(path: Routes.login, builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.chats, builder: (context, state) => const ChatsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.settings, builder: (context, state) => const SettingsScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:sessionId',
        builder: (context, state) => ConversationScreen(sessionId: state.pathParameters['sessionId'] ?? ''),
      ),
    ],
  );
});
