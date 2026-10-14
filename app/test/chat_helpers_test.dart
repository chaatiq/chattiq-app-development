import 'package:chattiq_app/core/dates.dart';
import 'package:chattiq_app/features/chats/chat_helpers.dart';
import 'package:chattiq_app/features/chats/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

ChatSession _session(Map<String, dynamic> json) => ChatSession.fromJson({'session_id': 's1', ...json});

void main() {
  group('IST dates', () {
    test('server time without a zone is UTC, shown in IST', () {
      // 10:00 UTC = 15:30 IST
      expect(formatTime('2026-10-06T10:00:00'), '03:30 pm');
      expect(formatTime('2026-10-06T10:00:00Z'), '03:30 pm');
      expect(formatTime('2026-10-06T00:15:00+00:00'), '05:45 am');
    });

    test('list time: today shows the time, yesterday says Yesterday, older a short date', () {
      final now = DateTime.utc(2026, 10, 6, 12);
      expect(formatChatListTime('2026-10-06T08:00:00Z', now: now), '01:30 pm');
      expect(formatChatListTime('2026-10-05T08:00:00Z', now: now), 'Yesterday');
      expect(formatChatListTime('2026-10-01T08:00:00Z', now: now), '01 Oct');
    });

    test('the IST day changes at 18:30 UTC', () {
      expect(istDayKey(DateTime.utc(2026, 10, 6, 18, 29)), '2026-10-06');
      expect(istDayKey(DateTime.utc(2026, 10, 6, 18, 30)), '2026-10-07');
    });

    test('date chip for older days', () {
      expect(formatDateChip('2026-10-05T08:00:00Z', now: DateTime.utc(2026, 10, 9)), 'Mon, 5 Oct 2026');
      expect(formatDateChip(null), 'Earlier');
    });
  });

  group('chat titles (same as the web inbox)', () {
    test('name, else WhatsApp number from the session id, else email, else channel', () {
      expect(
        chatDisplayTitle(
          _session({
            'contact': {'name': 'Rahul'},
          }),
        ),
        'Rahul',
      );
      expect(chatDisplayTitle(ChatSession.fromJson({'session_id': 'whatsapp_1_2_919876543210'})), '+919876543210');
      expect(
        chatDisplayTitle(
          _session({
            'contact': {'email': 'a@b.com'},
          }),
        ),
        'a@b.com',
      );
      expect(chatDisplayTitle(_session({'channel': 'whatsapp'})), 'WhatsApp user');
      expect(chatDisplayTitle(_session({})), 'Website visitor');
    });

    test('initials: last two digits for numbers, first letters for names', () {
      expect(
        avatarInitials(
          _session({
            'contact': {'name': 'Priya Verma'},
          }),
        ),
        'PV',
      );
      expect(avatarInitials(ChatSession.fromJson({'session_id': 'whatsapp_1_2_919876543210'})), '10');
    });

    test('status labels', () {
      expect(statusLabel(_session({})).text, 'Active');
      expect(
        statusLabel(_session({'status': 'completed', 'completion_reason': 'idle_timeout'})).text,
        'Completed · Idle',
      );
    });
  });

  group('search, filter and order', () {
    final chats = [
      _session({
        'session_id': 'a',
        'contact': {'name': 'Rahul', 'phone': '+91 98765 43210'},
        'last_activity_at': '2026-10-06T08:00:00Z',
      }),
      _session({
        'session_id': 'b',
        'contact': {'name': 'Priya'},
        'status': 'completed',
        'last_activity_at': '2026-10-06T09:00:00Z',
      }),
      _session({'session_id': 'c', 'agent_name': 'Clinic Bot', 'last_activity_at': '2026-10-06T07:00:00Z'}),
    ];

    test('newest first', () {
      expect(filterAndSortChats(chats, search: '', status: StatusFilter.all).map((c) => c.sessionId), ['b', 'a', 'c']);
    });

    test('status filter', () {
      expect(filterAndSortChats(chats, search: '', status: StatusFilter.completed).map((c) => c.sessionId), ['b']);
      expect(filterAndSortChats(chats, search: '', status: StatusFilter.active).map((c) => c.sessionId), ['a', 'c']);
    });

    test('search by name, agent, or digits of the phone', () {
      expect(filterAndSortChats(chats, search: 'priya', status: StatusFilter.all).single.sessionId, 'b');
      expect(filterAndSortChats(chats, search: 'clinic', status: StatusFilter.all).single.sessionId, 'c');
      expect(filterAndSortChats(chats, search: '98765', status: StatusFilter.all).single.sessionId, 'a');
    });
  });
}
