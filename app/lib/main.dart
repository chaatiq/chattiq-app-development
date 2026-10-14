import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_models.dart';
import 'features/chats/inbox_controller.dart';
import 'features/notifications/push_controller.dart';
import 'features/notifications/push_payload.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Reads android/app/google-services.json. Without it the app still works, without notifications.
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('Firebase is not set up; message notifications are off: $error');
  }
  runApp(const ProviderScope(child: ChattiqApp()));
}

class ChattiqApp extends ConsumerStatefulWidget {
  const ChattiqApp({super.key});

  @override
  ConsumerState<ChattiqApp> createState() => _ChattiqAppState();
}

class _ChattiqAppState extends ConsumerState<ChattiqApp> {
  StreamSubscription<NewMessagePayload>? _taps;
  StreamSubscription<NewMessagePayload>? _foreground;

  @override
  void initState() {
    super.initState();
    final platform = ref.read(pushPlatformProvider);
    _taps = platform.taps.listen(_openChat);
    // Show a new message at once instead of waiting for the next refresh.
    _foreground = platform.foregroundMessages.listen((_) => ref.read(inboxControllerProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _taps?.cancel();
    _foreground?.cancel();
    super.dispose();
  }

  /// A tapped notification opens its chat (only when signed in).
  void _openChat(NewMessagePayload message) {
    if (ref.read(authControllerProvider).status != AuthStatus.signedIn) return;
    ref.read(routerProvider).push(Routes.chat(message.sessionId));
  }

  @override
  Widget build(BuildContext context) {
    // Keeps notification registration running for the signed-in user.
    ref.watch(pushControllerProvider);
    return MaterialApp.router(
      title: 'Chattiq',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
