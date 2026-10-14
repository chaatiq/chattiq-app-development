import 'package:device_info_plus/device_info_plus.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/token_storage.dart';
import 'auth_models.dart';

class AuthApi {
  AuthApi(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  /// e.g. "Xiaomi 2312DRAABI"; stored with the session so devices can be told apart.
  Future<String> _deviceName() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final name = [info.manufacturer, info.model].where((part) => part.trim().isNotEmpty).join(' ');
      return name.length > 120 ? name.substring(0, 120) : name;
    } catch (_) {
      return '';
    }
  }

  /// Checks the email/user name and password; saves the tokens on success.
  Future<AppUser> login(String email, String password) async {
    final data = await _api.post(
      '/auth/login',
      auth: false,
      body: {
        'email': email.trim(),
        'password': password,
        // "mobile" also issues a 30-day refresh token.
        'client': 'mobile',
        'deviceName': await _deviceName(),
      },
    );
    if (data is! Map || data['accessToken'] is! String || data['user'] is! Map) {
      throw ApiException('Unexpected response from the server. Try again.', code: ApiErrorCode.unknown);
    }
    await _tokens.save(
      TokenPair(accessToken: data['accessToken'] as String, refreshToken: data['refreshToken'] as String?),
    );
    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  /// The signed-in user; throws ApiException(401) when the session is gone.
  Future<AppUser> currentUser() async {
    final data = await _api.get('/auth/check-auth');
    if (data is! Map || data['user'] is! Map) {
      throw ApiException('Unexpected response from the server.', code: ApiErrorCode.unknown);
    }
    return AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
  }

  /// Ends the session on the server (best effort) and always clears local tokens,
  /// so logging out works without a connection.
  Future<void> logout() async {
    final refreshToken = await _tokens.refreshToken();
    try {
      if (refreshToken != null) {
        await _api.post(
          '/auth/logout-mobile',
          auth: false,
          body: {'refreshToken': refreshToken},
          timeout: const Duration(seconds: 5),
        );
      }
    } catch (_) {
      // Ignore: local sign-out must not depend on the network.
    } finally {
      await _tokens.clear();
    }
  }
}
