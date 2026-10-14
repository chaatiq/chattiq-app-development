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

/// A chat server in memory: takeover state, sent replies.
class _FakeChatsApi extends ChatsApi {
  _FakeChatsApi() : super(ApiClient(tokens: MemoryTokenStorage(), baseUrl: 'http://test/api'));

  static const whatsappId = 'whatsapp_1_2_919876543210';
  static const websiteId = 'widget_1';

  bool takeover = false;
  final replies = <String>[];
  final now = DateTime.now().toUtc();

  Map<String, dynamic> _session(String id) => {
    'session_id': id,
    'contact': {'name': id == whatsappId ? 'Rahul Sharma' : 'Priya Verma'},
    'agent_name': 'Clinic Bot',
    'channel_label': id == whatsappId ? 'WhatsApp' : 'Website',
    'human_takeover': id == whatsappId && takeover,
    'last_activity_at': now.toIso8601String(),
  };

  @override
  Future<List<ChatSession>> fetchInbox() async => [
    ChatSession.fromJson(_session(whatsappId)),
    ChatSession.fromJson(_session(websiteId)),
  ];

  @override
  Future<ChatDetail> fetchChat(String sessionId) async => ChatDetail(
    session: ChatSession.fromJson(_session(sessionId)),
    messages: [
      ChatMessage(
        role: 'user',
        content: 'Do you have a slot?',
        timestamp: now.subtract(const Duration(minutes: 5)).toIso8601String(),
      ),
      ChatMessage(role: 'assistant', content: 'Yes, on **Wednesday**.', timestamp: now.toIso8601String()),
      for (final reply in replies) ChatMessage(role: 'assistant', content: reply, timestamp: now.toIso8601String()),
    ],
  );

  @override
  Future<void> markRead(String sessionId) async {}

  @override
  Future<void> sendTyping(String sessionId) async {}

  @override
  Future<void> setTakeover(String sessionId, {required bool active, String? agentId}) async => takeover = active;

  @override
  Future<ReplyResult> sendHumanReply(String sessionId, String message, {required bool confirmCharge}) async {
    replies.add(message);
    return ReplySent(message);
  }
}

Future<_FakeChatsApi> _open(WidgetTester tester, String chatName) async {
  final api = _FakeChatsApi();
  final tokens = MemoryTokenStorage(const TokenPair(accessToken: 'a', refreshToken: 'r'));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        pushPlatformProvider.overrideWithValue(FakePushPlatform()),
        authApiProvider.overrideWith((ref) => FakeAuthApi(ref.watch(apiClientProvider), tokens)),
        chatsApiProvider.overrideWithValue(api),
      ],
      child: const ChattiqApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(chatName));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('WhatsApp chat: Stop AI, reply, Resume AI', (tester) async {
    final api = await _open(tester, 'Rahul Sharma');

    expect(find.text('Yes, on Wednesday.', findRichText: true), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('24h window open'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('AI is answering · stop AI to take over'), findsOneWidget);

    await tester.tap(find.text('Stop AI & chat'));
    await tester.pumpAndSettle();
    expect(api.takeover, isTrue);
    expect(find.text('Human'), findsOneWidget);
    expect(find.text('Resume AI'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'I will check and confirm.');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pumpAndSettle();
    expect(api.replies, ['I will check and confirm.']);
    expect(find.text('I will check and confirm.', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Resume AI'));
    await tester.pumpAndSettle();
    expect(api.takeover, isFalse);
    expect(find.text('Stop AI & chat'), findsOneWidget);
  });

  testWidgets('website chatbot chats are not listed', (tester) async {
    await _open(tester, 'Rahul Sharma');
    await tester.tap(find.byTooltip('Back to chats'));
    await tester.pumpAndSettle();

    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('Priya Verma'), findsNothing);
  });
}
