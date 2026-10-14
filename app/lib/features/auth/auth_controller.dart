import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/providers.dart';
import '../notifications/push_controller.dart';
import 'auth_models.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Signed-in state for the whole app.
///
/// On launch it restores the stored session. A network failure keeps the user
/// signed in (the tokens are still valid); only a rejected session signs them out.
class AuthController extends Notifier<AuthState> {
  bool _signingOut = false;

  @override
  AuthState build() {
    ref.read(apiClientProvider).onSessionExpired = _sessionExpired;
    unawaited(Future.microtask(_restore));
    return const AuthState.loading();
  }

  Future<void> _restore() async {
    final tokens = await ref.read(tokenStorageProvider).load();
    if (tokens == null) {
      state = const AuthState.signedOut();
      return;
    }
    try {
      final user = await ref.read(authApiProvider).currentUser();
      state = AuthState(AuthStatus.signedIn, user: user);
    } on ApiException catch (error) {
      if (error.status == 401 || error.status == 403) {
        await ref.read(tokenStorageProvider).clear();
        state = const AuthState.signedOut();
      } else {
        state = const AuthState(AuthStatus.signedIn);
      }
    }
  }

  Future<void> signIn(String email, String password) async {
    final user = await ref.read(authApiProvider).login(email, password);
    state = AuthState(AuthStatus.signedIn, user: user);
  }

  Future<void> signOut() async {
    if (_signingOut) return;
    _signingOut = true;
    try {
      // Stop notifications to this phone first, while the access token still works.
      // Uses the devices API directly: the push controller depends on this
      // controller, so reading it from here would be a circular dependency.
      try {
        await ref.read(devicesApiProvider).unregisterCurrent();
      } catch (_) {
        // Best effort; the backend also drops the phone once Firebase reports it gone.
      }
      await ref.read(authApiProvider).logout();
    } finally {
      _signingOut = false;
      state = const AuthState.signedOut();
    }
  }

  /// A request found the session gone for good: back to the login screen.
  void _sessionExpired() {
    if (_signingOut || state.status == AuthStatus.signedOut) return;
    unawaited(ref.read(tokenStorageProvider).clear());
    state = const AuthState.signedOut();
  }
}
