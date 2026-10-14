import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenPair {
  const TokenPair({required this.accessToken, this.refreshToken});

  final String accessToken;

  /// Long-lived token for staying signed in (30 days), or null.
  final String? refreshToken;
}

/// Tokens live in the Android Keystore (encrypted) and are cached in memory
/// so each request does not read secure storage.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'chattiq.accessToken';
  static const _refreshKey = 'chattiq.refreshToken';

  final FlutterSecureStorage _storage;
  TokenPair? _cache;
  bool _loaded = false;

  Future<TokenPair?> load() async {
    if (_loaded) return _cache;
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    _cache = access == null ? null : TokenPair(accessToken: access, refreshToken: refresh);
    _loaded = true;
    return _cache;
  }

  Future<String?> accessToken() async => (await load())?.accessToken;

  Future<String?> refreshToken() async => (await load())?.refreshToken;

  Future<void> save(TokenPair tokens) async {
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    if (tokens.refreshToken != null) {
      await _storage.write(key: _refreshKey, value: tokens.refreshToken);
    } else {
      await _storage.delete(key: _refreshKey);
    }
    _cache = tokens;
    _loaded = true;
  }

  Future<void> clear() async {
    _cache = null;
    _loaded = true;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
