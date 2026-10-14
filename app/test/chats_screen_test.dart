import 'package:chattiq_app/features/notifications/push_controller.dart';
import 'package:chattiq_app/core/api/api_client.dart';
import 'package:chattiq_app/core/auth/token_storage.dart';
import 'package:chattiq_app/core/providers.dart';
import 'package:chattiq_app/features/chats/chat_models.dart';
import 'package:chattiq_app/features/chats/chats_api.dart';
import 'package:chattiq_app/features/chats/inbox_controller.dart';
import 'package:chattiq_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

class _FakeChatsApi extends ChatsApi {
  _FakeChatsApi(this.chats) : super(ApiClient(tokens: MemoryTokenStorage(), baseUrl: 'http://test/api'));

  final List<ChatSession> chats;

  @override
  Future<List<ChatSession>> fetchInbox() async => chats;
}

void main() {
  testWidgets('signed in: the Chats tab lists chats and filters them', (tester) async {
    final tokens = MemoryTokenStorage(const TokenPair(accessToken: 'a', refreshToken: 'r'));
    final chats = [
      ChatSession.fromJson({
        'session_id': 'whatsapp_1_2_919876543210',
        'contact': {'name': 'Rahul Sharma'},
        'agent_name': 'Clinic Bot',
        'message_count': 2,
        'last_activity_at': DateTime.now().toUtc().toIso8601String(),
      }),
      ChatSession.fromJson({
        'session_id': 'whatsapp_1_2_919811112222',
        'contact': {'name': 'Priya Verma'},
        'status': 'completed',
        'message_count': 3,
      }),
      // Website chatbot chat: not shown, the app is for WhatsApp agents only.
      ChatSession.fromJson({
        'session_id': 'widget_1',
        'contact': {'name': 'Website Visitor'},
        'channel': 'website',
        'message_count': 1,
      }),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokens),
          pushPlatformProvider.overrideWithValue(FakePushPlatform()),
          // Signed in without calling the network: check-auth is answered by a fake.
          authApiProvider.overrideWith((ref) => FakeAuthApi(ref.watch(apiClientProvider), tokens)),
          chatsApiProvider.overrideWithValue(_FakeChatsApi(chats)),
        ],
        child: const ChattiqApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chats'), findsWidgets);
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('Priya Verma'), findsOneWidget);
    expect(find.text('Website Visitor'), findsNothing);
    expect(find.text('+919876543210'), findsOneWidget); // phone line under the name

    await tester.tap(find.byKey(const ValueKey('filter-completed')));
    await tester.pumpAndSettle();
    expect(find.text('Rahul Sharma'), findsNothing);
    expect(find.text('Priya Verma'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('filter-all')));
    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No chats match “nobody”'), findsOneWidget);
  });
}
