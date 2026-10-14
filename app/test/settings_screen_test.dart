import 'package:chattiq_app/features/notifications/push_controller.dart';
import 'package:chattiq_app/core/api/api_client.dart';
import 'package:chattiq_app/core/api/api_exception.dart';
import 'package:chattiq_app/core/auth/token_storage.dart';
import 'package:chattiq_app/core/providers.dart';
import 'package:chattiq_app/features/chats/chat_models.dart';
import 'package:chattiq_app/features/chats/chats_api.dart';
import 'package:chattiq_app/features/chats/inbox_controller.dart';
import 'package:chattiq_app/features/settings/notification_settings.dart';
import 'package:chattiq_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

ApiClient _unusedClient() => ApiClient(tokens: MemoryTokenStorage(), baseUrl: 'http://test/api');

class _EmptyChatsApi extends ChatsApi {
  _EmptyChatsApi() : super(_unusedClient());

  @override
  Future<List<ChatSession>> fetchInbox() async => const [];
}

/// The server setting in memory; can be told to fail the next save.
class _FakeSettingsApi extends NotificationSettingsApi {
  _FakeSettingsApi() : super(_unusedClient());

  bool enabled = true;
  bool failNextSave = false;

  @override
  Future<bool> fetch() async => enabled;

  @override
  Future<bool> update({required bool enabled}) async {
    if (failNextSave) {
      failNextSave = false;
      throw ApiException(
        "Can't reach the server. Check your internet connection and try again.",
        code: ApiErrorCode.network,
      );
    }
    this.enabled = enabled;
    return enabled;
  }
}

Future<_FakeSettingsApi> _openSettings(WidgetTester tester) async {
  final settingsApi = _FakeSettingsApi();
  final tokens = MemoryTokenStorage(const TokenPair(accessToken: 'a', refreshToken: 'r'));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        pushPlatformProvider.overrideWithValue(FakePushPlatform()),
        authApiProvider.overrideWith((ref) => FakeAuthApi(ref.watch(apiClientProvider), tokens)),
        chatsApiProvider.overrideWithValue(_EmptyChatsApi()),
        notificationSettingsApiProvider.overrideWithValue(settingsApi),
      ],
      child: const ChattiqApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings').last);
  await tester.pumpAndSettle();
  return settingsApi;
}

void _expectSelected(WidgetTester tester, String key) =>
    expect(tester.getSemantics(find.byKey(ValueKey(key))), isSemantics(isChecked: true));

void main() {
  testWidgets('shows the saved setting and switches it off and on', (tester) async {
    final api = await _openSettings(tester);

    expect(find.text('Message notifications'), findsWidgets);
    expect(find.text('Local Dev'), findsOneWidget);
    _expectSelected(tester, 'notifications-on');

    await tester.tap(find.byKey(const ValueKey('notifications-off')));
    await tester.pumpAndSettle();
    expect(api.enabled, isFalse);
    _expectSelected(tester, 'notifications-off');

    await tester.tap(find.byKey(const ValueKey('notifications-on')));
    await tester.pumpAndSettle();
    expect(api.enabled, isTrue);
  });

  testWidgets('a failed save puts the choice back and explains why', (tester) async {
    final api = await _openSettings(tester);
    api.failNextSave = true;

    await tester.tap(find.byKey(const ValueKey('notifications-off')));
    await tester.pumpAndSettle();

    expect(api.enabled, isTrue);
    _expectSelected(tester, 'notifications-on');
    expect(find.textContaining("Can't reach the server"), findsOneWidget);
  });
}
