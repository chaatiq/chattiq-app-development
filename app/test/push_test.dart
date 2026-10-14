import 'package:chattiq_app/core/api/api_client.dart';
import 'package:chattiq_app/core/auth/token_storage.dart';
import 'package:chattiq_app/core/providers.dart';
import 'package:chattiq_app/features/chats/chat_models.dart';
import 'package:chattiq_app/features/chats/chats_api.dart';
import 'package:chattiq_app/features/chats/inbox_controller.dart';
import 'package:chattiq_app/features/conversation/conversation_screen.dart';
import 'package:chattiq_app/features/notifications/push_controller.dart';
import 'package:chattiq_app/features/notifications/push_payload.dart';
import 'package:chattiq_app/features/notifications/push_platform.dart';
import 'package:chattiq_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

ApiClient _client() => ApiClient(tokens: MemoryTokenStorage(), baseUrl: 'http://test/api');

class _ChatsApi extends ChatsApi {
  _ChatsApi() : super(_client());

  @override
  Future<List<ChatSession>> fetchInbox() async => const [];

  @override
  Future<ChatDetail> fetchChat(String sessionId) async => ChatDetail(
    session: ChatSession.fromJson({
      'session_id': sessionId,
      'contact': {'name': 'Rahul Sharma'},
    }),
  );

  @override
  Future<void> markRead(String sessionId) async {}
}

Future<(FakePushPlatform, FakeDevicesApi)> _start(WidgetTester tester, FakePushPlatform platform) async {
  final tokens = MemoryTokenStorage(const TokenPair(accessToken: 'a', refreshToken: 'r'));
  final devices = FakeDevicesApi(_client());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        authApiProvider.overrideWith((ref) => FakeAuthApi(ref.watch(apiClientProvider), tokens)),
        chatsApiProvider.overrideWithValue(_ChatsApi()),
        pushPlatformProvider.overrideWithValue(platform),
        devicesApiProvider.overrideWithValue(devices),
      ],
      child: const ChattiqApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (platform, devices);
}

void main() {
  test('only "new_message" data with a chat id opens a chat', () {
    expect(NewMessagePayload.fromData({'type': 'new_message', 'sessionId': 's1'})?.sessionId, 's1');
    expect(NewMessagePayload.fromData({'type': 'other', 'sessionId': 's1'}), isNull);
    expect(NewMessagePayload.fromData({'type': 'new_message', 'sessionId': ''}), isNull);
  });

  testWidgets('after sign-in: asks once, then registers this phone', (tester) async {
    final (platform, devices) = await _start(
      tester,
      FakePushPlatform(current: PushPermission.notDetermined, afterRequest: PushPermission.granted, pushToken: 'fcm-1'),
    );

    expect(platform.requests, 1);
    expect(devices.registered, ['fcm-1']);
  });

  testWidgets('permission refused: nothing is registered', (tester) async {
    final (_, devices) = await _start(
      tester,
      FakePushPlatform(current: PushPermission.notDetermined, afterRequest: PushPermission.denied, pushToken: 'fcm-1'),
    );

    expect(devices.registered, isEmpty);
  });

  testWidgets('tapping a notification opens that chat', (tester) async {
    final (platform, _) = await _start(tester, FakePushPlatform(current: PushPermission.granted, pushToken: 'fcm-1'));

    platform.tapController.add(const NewMessagePayload(sessionId: 'whatsapp_1_2_919876543210'));
    await tester.pumpAndSettle();

    expect(find.byType(ConversationScreen), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsOneWidget);
  });
}
