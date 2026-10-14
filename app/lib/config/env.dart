import 'package:flutter/foundation.dart';

/// Build-time settings, passed with
/// `flutter run --dart-define-from-file=config/dev.json` (see config/dev.example.json).
abstract final class Env {
  static const _apiUrl = String.fromEnvironment('API_URL');
  static const _webUrl = String.fromEnvironment('WEB_URL');

  /// Android emulator address of the laptop running the backend (port 5002).
  static const _emulatorApiUrl = 'http://10.0.2.2:5002/api';

  /// Mobile backend base URL, ending in /api, without a trailing slash.
  static String get apiUrl {
    if (_apiUrl.isNotEmpty) return _stripSlash(_apiUrl);
    if (kDebugMode) return _emulatorApiUrl;
    throw StateError('API_URL is not set. Build with --dart-define-from-file=config/<env>.json.');
  }

  /// Web dashboard origin, for the Sign up / Forgot password / Privacy links. Empty hides them.
  static String get webUrl => _stripSlash(_webUrl);

  static String _stripSlash(String url) => url.replaceAll(RegExp(r'/+$'), '');
}

/// Request timeout for API calls.
const apiTimeout = Duration(seconds: 15);
