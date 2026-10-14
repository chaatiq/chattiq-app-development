import 'package:chattiq_app/core/api/api_client.dart';
import 'package:chattiq_app/core/api/api_exception.dart';
import 'package:chattiq_app/core/auth/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

const _base = 'http://test/api';

/// A client whose main requests and refresh requests share one fake server.
(ApiClient, FakeAdapter) _client(MemoryTokenStorage tokens, FakeHandler handler) {
  final adapter = FakeAdapter(handler);
  final client = ApiClient(
    tokens: tokens,
    baseUrl: _base,
    dio: Dio(BaseOptions(baseUrl: _base))..httpClientAdapter = adapter,
  );
  client.refreshDioForTest.httpClientAdapter = adapter;
  return (client, adapter);
}

void main() {
  test('sends the access token as a Bearer header', () async {
    final tokens = MemoryTokenStorage(const TokenPair(accessToken: 'a1', refreshToken: 'r1'));
    final (client, adapter) = _client(tokens, (_) async => (200, {'ok': true}));

    await client.get('/dashboard/sessions');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer a1');
  });

  test('on 401 it refreshes once and retries with the new token', () async {
    final tokens = MemoryTokenStorage(const TokenPair(accessToken: 'old', refreshToken: 'r1'));
    final (client, adapter) = _client(tokens, (request) async {
      if (request.path == '/auth/refresh') return (200, {'accessToken': 'new', 'refreshToken': 'r2'});
      final auth = request.headers['Authorization'];
      return auth == 'Bearer new' ? (200, {'ok': true}) : (401, {'message': 'Unauthorised'});
    });

    expect(await client.get('/dashboard/sessions'), {'ok': true});
    expect(tokens.tokens?.accessToken, 'new');
    expect(tokens.tokens?.refreshToken, 'r2');
  });

  test('parallel 401s share one refresh', () async {
    final tokens = MemoryTokenStorage(const TokenPair(accessToken: 'old', refreshToken: 'r1'));
    var refreshes = 0;
    final (client, _) = _client(tokens, (request) async {
      if (request.path == '/auth/refresh') {
        refreshes += 1;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return (200, {'accessToken': 'new', 'refreshToken': 'r2'});
      }
      return request.headers['Authorization'] == 'Bearer new' ? (200, {'ok': true}) : (401, {});
    });

    await Future.wait([client.get('/a'), client.get('/b'), client.get('/c')]);

    expect(refreshes, 1);
  });

  test('a rejected refresh clears the tokens and reports the expired session', () async {
    final tokens = MemoryTokenStorage(const TokenPair(accessToken: 'old', refreshToken: 'r1'));
    var expired = false;
    final (client, _) = _client(tokens, (request) async {
      if (request.path == '/auth/refresh') return (401, {'message': 'Session ended'});
      return (401, {'message': 'Unauthorised'});
    });
    client.onSessionExpired = () => expired = true;

    await expectLater(
      client.get('/dashboard/sessions'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
    expect(tokens.tokens, isNull);
    expect(expired, isTrue);
  });

  test('server down during refresh keeps the user signed in', () async {
    final tokens = MemoryTokenStorage(const TokenPair(accessToken: 'old', refreshToken: 'r1'));
    var expired = false;
    final (client, _) = _client(tokens, (request) async {
      if (request.path == '/auth/refresh') return (503, {'message': 'Down'});
      return (401, {});
    });
    client.onSessionExpired = () => expired = true;

    await expectLater(client.get('/x'), throwsA(isA<ApiException>()));
    expect(tokens.tokens?.refreshToken, 'r1');
    expect(expired, isFalse);
  });

  test('server error messages reach the user', () async {
    final tokens = MemoryTokenStorage();
    final (client, _) = _client(tokens, (_) async => (401, {'success': false, 'message': 'Incorrect password'}));

    await expectLater(
      client.post('/auth/login', auth: false, body: {}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Incorrect password')),
    );
  });
}
