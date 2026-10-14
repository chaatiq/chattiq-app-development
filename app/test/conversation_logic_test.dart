import 'package:chattiq_app/core/api/api_client.dart';
import 'package:chattiq_app/features/chats/chat_helpers.dart';
import 'package:chattiq_app/features/chats/chat_models.dart';
import 'package:chattiq_app/features/chats/chats_api.dart';
import 'package:chattiq_app/features/conversation/widgets/message_bubble.dart';
import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

ChatMessage _msg(String role, String content, String time) =>
    ChatMessage(role: role, content: content, timestamp: time);

void main() {
  group('message text', () {
    const base = TextStyle(fontSize: 14);

    test('**bold** and WhatsApp *bold* become bold spans', () {
      final spans = formatMessageSpans('Slots on **Wednesday** and *Friday*.', base);
      expect(spans.map((span) => span.text), ['Slots on ', 'Wednesday', ' and ', 'Friday', '.']);
      expect(spans[1].style?.fontWeight, FontWeight.w700);
      expect(spans[3].style?.fontWeight, FontWeight.w700);
    });

    test('dash and star bullets become •', () {
      final spans = formatMessageSpans('- one\n* two', base);
      expect(spans.map((span) => span.text).join(), '• one\n• two');
    });
  });

  group('timeline', () {
    test('drops empty lines and system errors', () {
      final visible = visibleMessages([
        _msg('user', 'hi', '2026-10-06T08:00:00Z'),
        _msg('assistant', '  ', '2026-10-06T08:00:01Z'),
        _msg('system', 'Error: boom', '2026-10-06T08:00:02Z'),
      ]);
      expect(visible.length, 1);
    });

    test('a date chip whenever the IST day changes', () {
      final items = buildTimeline([
        _msg('user', 'a', '2026-10-05T10:00:00Z'),
        _msg('assistant', 'b', '2026-10-05T10:01:00Z'),
        _msg('user', 'c', '2026-10-06T10:00:00Z'),
      ], now: DateTime.utc(2026, 10, 6, 12));
      expect(items.map((item) => item is DateItem ? item.label : 'msg'), ['Yesterday', 'msg', 'msg', 'Today', 'msg']);
    });
  });

  group('24-hour window', () {
    final now = DateTime.utc(2026, 10, 6, 12);

    test('open, counted from the last customer message', () {
      final window = serviceWindowFromMessages([
        _msg('user', 'hi', '2026-10-06T10:00:00Z'),
        _msg('assistant', 'hello', '2026-10-06T11:00:00Z'),
      ], now: now);
      expect(window.open, isTrue);
      expect(formatWindowCountdown(window.secondsRemaining), '22h 0m left');
    });

    test('closed after 24 hours or without a customer message', () {
      expect(serviceWindowFromMessages([_msg('user', 'hi', '2026-10-05T11:00:00Z')], now: now).open, isFalse);
      expect(serviceWindowFromMessages([_msg('assistant', 'hello', '2026-10-06T11:00:00Z')], now: now).open, isFalse);
    });
  });

  group('human reply', () {
    ChatsApi api((int, Object?) response) {
      final adapter = FakeAdapter((_) async => response);
      final client = ApiClient(
        tokens: MemoryTokenStorage(),
        baseUrl: 'http://test/api',
        dio: Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = adapter,
      );
      return ChatsApi(client);
    }

    test('402 means the Meta charge must be confirmed', () async {
      expect(
        await api((402, {'detail': 'charge'})).sendHumanReply('whatsapp_1', 'hi', confirmCharge: false),
        isA<ReplyNeedsChargeConfirm>(),
      );
    });

    test('needs_charge_confirm in the body also asks for confirmation', () async {
      expect(
        await api((200, {'needs_charge_confirm': true})).sendHumanReply('whatsapp_1', 'hi', confirmCharge: false),
        isA<ReplyNeedsChargeConfirm>(),
      );
    });

    test('sent: returns the stored text', () async {
      final result = await api((200, {'success': true, 'message': 'hi!'}))
          .sendHumanReply('whatsapp_1', 'hi', confirmCharge: false);
      expect(result, isA<ReplySent>().having((sent) => sent.message, 'message', 'hi!'));
    });
  });
}
