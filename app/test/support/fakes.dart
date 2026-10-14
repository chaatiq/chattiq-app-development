import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chattiq_app/core/auth/token_storage.dart';
import 'package:chattiq_app/features/auth/auth_api.dart';
import 'package:chattiq_app/features/auth/auth_models.dart';
import 'package:chattiq_app/features/notifications/devices_api.dart';
import 'package:chattiq_app/features/notifications/push_payload.dart';
import 'package:chattiq_app/features/notifications/push_platform.dart';
import 'package:dio/dio.dart';

/// Signed-in user without a network call.
class FakeAuthApi extends AuthApi {
  FakeAuthApi(super.api, super.tokens);

  static const user = AppUser(id: 'user-1', email: 'dev@chattiq.dev', userName: 'Local Dev');

  @override
  Future<AppUser> currentUser() async => user;
}

/// In-memory stand-in for the Android Keystore storage.
class MemoryTokenStorage extends TokenStorage {
  MemoryTokenStorage([this.tokens]);

  TokenPair? tokens;

  @override
  Future<TokenPair?> load() async => tokens;

  @override
  Future<String?> accessToken() async => tokens?.accessToken;

  @override
  Future<String?> refreshToken() async => tokens?.refreshToken;

  @override
  Future<void> save(TokenPair value) async => tokens = value;

  @override
  Future<void> clear() async => tokens = null;
}

typedef FakeHandler = Future<(int, Object?)> Function(RequestOptions request);

/// Answers Dio requests from a function instead of the network, and records them.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FakeHandler handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = await handler(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Notifications without Firebase: permission, token and taps are set by the test.
class FakePushPlatform implements PushPlatform {
  FakePushPlatform({this.current = PushPermission.denied, this.afterRequest = PushPermission.denied, this.pushToken});

  PushPermission current;
  PushPermission afterRequest;
  String? pushToken;
  int requests = 0;
  final tapController = StreamController<NewMessagePayload>.broadcast();
  final foregroundController = StreamController<NewMessagePayload>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<PushPermission> permission() async => current;

  @override
  Future<PushPermission> requestPermission() async {
    requests += 1;
    return current = afterRequest;
  }

  @override
  Future<String?> token() async => pushToken;

  @override
  Stream<String> get tokenRefreshes => const Stream<String>.empty();

  @override
  Stream<NewMessagePayload> get taps => tapController.stream;

  @override
  Stream<NewMessagePayload> get foregroundMessages => foregroundController.stream;
}

/// Records registrations instead of calling the backend.
class FakeDevicesApi extends DevicesApi {
  FakeDevicesApi(super.api);

  final registered = <String>[];
  int unregistered = 0;

  @override
  Future<void> register(String pushToken) async => registered.add(pushToken);

  @override
  Future<void> unregisterCurrent() async => unregistered += 1;
}
