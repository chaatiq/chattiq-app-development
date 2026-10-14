import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'devices_api.dart';
import 'push_platform.dart';

final pushPlatformProvider = Provider<PushPlatform>((ref) => FirebasePushPlatform());

final devicesApiProvider = Provider<DevicesApi>((ref) => DevicesApi(ref.watch(apiClientProvider)));

/// Right after install or permission, Firebase may not be ready and getToken
/// can hang instead of failing; without a limit the phone never registered.
const _tokenTimeout = Duration(seconds: 15);

/// Waits before the 2nd and 3rd registration attempts.
const _retryDelays = [Duration(seconds: 5), Duration(seconds: 20)];

class PushState {
  const PushState({this.permission = PushPermission.notDetermined, this.registered = false});

  final PushPermission permission;

  /// True once this phone is registered with the backend.
  final bool registered;
}

final pushControllerProvider = NotifierProvider<PushController, PushState>(PushController.new);

/// For signed-in users: asks for notification permission once, registers this
/// phone, re-checks when the app returns from the background (the user may
/// have changed phone settings), and re-registers when the token changes.
class PushController extends Notifier<PushState> {
  StreamSubscription<String>? _tokenRefresh;
  AppLifecycleListener? _lifecycle;
  bool _registering = false;
  bool _signedIn = false;

  PushPlatform get _platform => ref.read(pushPlatformProvider);

  @override
  PushState build() {
    _signedIn = ref.watch(authControllerProvider.select((auth) => auth.status == AuthStatus.signedIn));
    ref.onDispose(() {
      _tokenRefresh?.cancel();
      _lifecycle?.dispose();
    });
    if (!_signedIn) return const PushState();

    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_sync(ask: false)));
    unawaited(Future.microtask(_start));
    return const PushState();
  }

  Future<void> _start() async {
    try {
      await _platform.init();
      _tokenRefresh = _platform.tokenRefreshes.listen((_) => unawaited(_register()));
      await _sync(ask: true);
    } catch (error) {
      debugPrint('Notification setup failed: $error');
    }
  }

  Future<void> _sync({required bool ask}) async {
    var permission = await _platform.permission();
    if (ask && permission == PushPermission.notDetermined) permission = await _platform.requestPermission();
    if (!ref.mounted) return;
    state = PushState(permission: permission, registered: state.registered);
    if (permission == PushPermission.granted) await _register();
  }

  /// Asks again, e.g. from Settings ("Allow notifications").
  Future<void> requestPermission() => _sync(ask: true);

  Future<void> _register() async {
    if (_registering) return;
    _registering = true;
    try {
      for (var attempt = 0; attempt <= _retryDelays.length; attempt++) {
        if (attempt > 0) await Future<void>.delayed(_retryDelays[attempt - 1]);
        // Signed out meanwhile: this phone must not be registered to anyone.
        if (!ref.mounted || !_signedIn) return;
        try {
          final token = await _platform.token().timeout(_tokenTimeout);
          if (token == null || token.isEmpty) continue;
          await ref.read(devicesApiProvider).register(token);
          if (ref.mounted) state = PushState(permission: state.permission, registered: true);
          return;
        } catch (error) {
          debugPrint('Could not register for notifications (attempt ${attempt + 1}): $error');
        }
      }
      // All attempts failed: the next resume or token change tries again.
    } finally {
      _registering = false;
    }
  }
}
