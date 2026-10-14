import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';

/// Server-side "Message notifications" setting (users.notify_new_lead).
class NotificationSettingsApi {
  NotificationSettingsApi(this._api);

  final ApiClient _api;

  static bool _parse(Object? data) => data is Map && data['notifyNewLead'] == true;

  Future<bool> fetch() async => _parse(await _api.get('/me/notification-settings'));

  Future<bool> update({required bool enabled}) async =>
      _parse(await _api.patch('/me/notification-settings', body: {'notifyNewLead': enabled}));
}

final notificationSettingsApiProvider = Provider<NotificationSettingsApi>(
  (ref) => NotificationSettingsApi(ref.watch(apiClientProvider)),
);

class NotificationSettingsState {
  const NotificationSettingsState({this.enabled, this.loadError, this.saveError, this.saving = false});

  /// Null until loaded.
  final bool? enabled;
  final Object? loadError;
  final Object? saveError;
  final bool saving;

  bool get loading => enabled == null && loadError == null;
}

final notificationSettingsProvider = NotifierProvider<NotificationSettingsController, NotificationSettingsState>(
  NotificationSettingsController.new,
);

/// Loads the setting after sign-in; changes are shown at once and rolled back if saving fails.
class NotificationSettingsController extends Notifier<NotificationSettingsState> {
  NotificationSettingsApi get _api => ref.read(notificationSettingsApiProvider);

  @override
  NotificationSettingsState build() {
    final signedIn = ref.watch(authControllerProvider.select((auth) => auth.status == AuthStatus.signedIn));
    if (signedIn) unawaited(Future.microtask(load));
    return const NotificationSettingsState();
  }

  Future<void> load() async {
    if (state.loadError != null) state = const NotificationSettingsState();
    try {
      final enabled = await _api.fetch();
      if (ref.mounted) state = NotificationSettingsState(enabled: enabled);
    } catch (error) {
      if (ref.mounted) state = NotificationSettingsState(loadError: error);
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final previous = state.enabled;
    if (previous == null || previous == enabled) return;
    state = NotificationSettingsState(enabled: enabled, saving: true);
    try {
      final saved = await _api.update(enabled: enabled);
      if (ref.mounted) state = NotificationSettingsState(enabled: saved);
    } catch (error) {
      if (ref.mounted) state = NotificationSettingsState(enabled: previous, saveError: error);
    }
  }
}
