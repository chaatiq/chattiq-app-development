import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api/api_client.dart';

/// Registers this phone with the backend so it receives message notifications.
class DevicesApi {
  DevicesApi(this._api, [FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  /// The token this phone last registered, so logout can unregister it.
  static const _registeredKey = 'chattiq.pushToken';

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  Future<String> _deviceName() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final name = [info.manufacturer, info.model].where((part) => part.trim().isNotEmpty).join(' ');
      return name.length > 120 ? name.substring(0, 120) : name;
    } catch (_) {
      return '';
    }
  }

  Future<String> _appVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return '';
    }
  }

  Future<void> register(String pushToken) async {
    await _api.post(
      '/devices',
      body: {
        'pushToken': pushToken,
        'platform': 'android',
        'deviceName': await _deviceName(),
        'appVersion': await _appVersion(),
      },
    );
    await _storage.write(key: _registeredKey, value: pushToken);
  }

  /// Stops notifications to this phone (on logout, before the tokens are cleared).
  /// Best effort: a failure never blocks logout.
  Future<void> unregisterCurrent() async {
    String? token;
    try {
      token = await _storage.read(key: _registeredKey);
    } catch (_) {
      return;
    }
    if (token == null) return;
    try {
      await _api.delete('/devices/${Uri.encodeComponent(token)}', timeout: const Duration(seconds: 5));
    } catch (_) {
      // The backend also stops sending once Firebase reports the token as gone.
    } finally {
      await _storage.delete(key: _registeredKey);
    }
  }
}
