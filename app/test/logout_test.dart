import 'package:chattiq_app/core/api/api_client.dart';
import 'package:chattiq_app/core/auth/token_storage.dart';
import 'package:chattiq_app/core/providers.dart';
import 'package:chattiq_app/features/auth/auth_controller.dart';
import 'package:chattiq_app/features/auth/auth_models.dart';
import 'package:chattiq_app/features/notifications/devices_api.dart';
import 'package:chattiq_app/features/notifications/push_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('log out removes this phone and ends the session on the server', () async {
    FlutterSecureStorage.setMockInitialValues({'chattiq.pushToken': 'fcm-token-1:abc'});
    final tokens = MemoryTokenStorage(TokenPair(accessToken: 'a', refreshToken: 'r' * 64));
    final adapter = FakeAdapter((request) async {
      if (request.path == '/auth/check-auth') {
        return (
          200,
          {
            'user': {'id': 'u1', 'email': 'dev@chattiq.dev'},
          },
        );
      }
      return (200, {'success': true});
    });
    final client = ApiClient(
      tokens: tokens,
      baseUrl: 'http://test/api',
      dio: Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = adapter,
    );

    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWithValue(client),
        pushPlatformProvider.overrideWithValue(FakePushPlatform()),
        devicesApiProvider.overrideWithValue(DevicesApi(client)),
      ],
    );
    addTearDown(container.dispose);

    container.read(authControllerProvider);
    // Wait for the stored session to be restored (check-auth).
    for (var i = 0; i < 100 && container.read(authControllerProvider).status != AuthStatus.signedIn; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(container.read(authControllerProvider).status, AuthStatus.signedIn);

    await container.read(authControllerProvider.notifier).signOut();

    final calls = adapter.requests.map((r) => '${r.method} ${r.path}').toList();
    expect(calls, contains('DELETE /devices/${Uri.encodeComponent('fcm-token-1:abc')}'));
    expect(calls, contains('POST /auth/logout-mobile'));
    expect(tokens.tokens, isNull);
    expect(container.read(authControllerProvider).status, AuthStatus.signedOut);
  });
}
