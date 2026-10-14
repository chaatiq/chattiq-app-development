/// Ported from web/components/chat-dashboard/ChatsInbox.jsx so the app reads
/// like the web inbox.
library;

import '../../core/dates.dart';
import 'chat_models.dart';

String formatDisplayPhone(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('+')) return value;
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 8) return '+$digits';
  return value;
}

/// Session ids look like whatsapp_{waba}_{phone_number_id}_{user_phone}.
String whatsAppPhoneFromSessionId(String sessionId) {
  if (!sessionId.startsWith('whatsapp_')) return '';
  final parts = sessionId.split('_');
  if (parts.length < 4) return '';
  return formatDisplayPhone(parts.last);
}

String parseWhatsAppPhone(ChatSession session) {
  final phone = session.contact.phone?.trim() ?? '';
  if (phone.isNotEmpty) return formatDisplayPhone(phone);
  return whatsAppPhoneFromSessionId(session.sessionId);
}

bool isWhatsAppSession(ChatSession session) =>
    session.sessionId.startsWith('whatsapp_') || session.channel == 'whatsapp';

String chatDisplayTitle(ChatSession session) {
  final name = session.contact.name?.trim() ?? '';
  if (name.isNotEmpty) return name;
  final phone = parseWhatsAppPhone(session);
  if (phone.isNotEmpty) return phone;
  final email = session.contact.email?.trim() ?? '';
  if (email.isNotEmpty) return email;
  if (session.channel == 'ai_agent') return 'Test conversation';
  if (session.channel == 'whatsapp') return 'WhatsApp user';
  return 'Website visitor';
}

/// Secondary line under the title: the phone when the name is known, else the email.
String chatContactSubtitle(ChatSession session) {
  final name = session.contact.name?.trim() ?? '';
  final phone = parseWhatsAppPhone(session);
  final email = session.contact.email?.trim() ?? '';
  if (name.isNotEmpty && phone.isNotEmpty) return phone;
  if (email.isNotEmpty && (name.isNotEmpty || phone.isNotEmpty)) return email;
  return '';
}

String avatarInitials(ChatSession session) {
  final title = chatDisplayTitle(session);
  final digits = title.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 2) return digits.substring(digits.length - 2);
  final words = title.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.length >= 2) return (words[0][0] + words[1][0]).toUpperCase();
  return title.isEmpty ? '?' : title[0].toUpperCase();
}

bool isCompleted(ChatSession session) => (session.status ?? '').toLowerCase() == 'completed';

bool isHumanTakeover(ChatSession session) => session.humanTakeover || session.aiPaused;

enum StatusTone { active, done }

({String text, StatusTone tone}) statusLabel(ChatSession session) {
  if (!isCompleted(session)) return (text: 'Active', tone: StatusTone.active);
  final reason = (session.completionReason ?? '').toLowerCase();
  if (reason == 'ai_resolved' || reason == 'agent_closed') return (text: 'Completed · AI', tone: StatusTone.done);
  if (reason == 'idle_timeout' || reason == 'inactivity') return (text: 'Completed · Idle', tone: StatusTone.done);
  if (reason == 'manual') return (text: 'Completed · Manual', tone: StatusTone.done);
  return (text: 'Completed', tone: StatusTone.done);
}

String completionReasonText(String? reason) {
  switch ((reason ?? '').toLowerCase()) {
    case 'ai_resolved':
    case 'agent_closed':
      return 'AI assisted';
    case 'idle_timeout':
      return 'Auto-closed after inactivity';
    case 'inactivity':
      return 'Auto-closed (widget idle)';
    case 'manual':
      return 'Marked manually';
    case 'user_closed':
      return 'User closed chat';
    default:
      return '';
  }
}

enum StatusFilter {
  all('All chats'),
  active('Active'),
  completed('Completed');

  const StatusFilter(this.label);
  final String label;

  bool matches(ChatSession session) => switch (this) {
    StatusFilter.all => true,
    StatusFilter.active => !isCompleted(session),
    StatusFilter.completed => isCompleted(session),
  };
}

/// Search across contact, agent, channel and summary (web sessionMatchesSearch).
bool sessionMatchesSearch(ChatSession session, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final contact = session.contact;
  final fields = [
    chatDisplayTitle(session),
    contact.name,
    contact.email,
    contact.phone,
    session.agentName,
    session.channelLabel,
    session.channel,
    session.summary,
    session.lastMessagePreview,
  ].whereType<String>().map((value) => value.toLowerCase());
  if (fields.any((field) => field.contains(q))) return true;

  final qDigits = q.replaceAll(RegExp(r'\D'), '');
  if (qDigits.length >= 3) {
    final phones = [contact.phone, chatDisplayTitle(session), parseWhatsAppPhone(session)].whereType<String>();
    return phones.any((phone) => phone.replaceAll(RegExp(r'\D'), '').contains(qDigits));
  }
  return false;
}

int sessionTimestamp(ChatSession session) =>
    parseServerDate(session.lastActivityAt ?? session.startedAt)?.millisecondsSinceEpoch ?? 0;

bool isUserMessage(String? role) {
  final value = (role ?? '').toLowerCase();
  return value == 'user' || value.contains('user');
}

/// Drops empty lines and system errors (web normalizeMessages).
List<ChatMessage> visibleMessages(List<ChatMessage> messages) => messages.where((message) {
  final content = (message.content ?? '').trim();
  if (content.isEmpty) return false;
  final role = (message.role ?? '').toLowerCase();
  return !(role == 'system' && content.toLowerCase().contains('error'));
}).toList();

sealed class TimelineItem {
  const TimelineItem(this.key);
  final String key;
}

class DateItem extends TimelineItem {
  const DateItem(super.key, this.label);
  final String label;
}

class MessageItem extends TimelineItem {
  const MessageItem(super.key, this.message);
  final ChatMessage message;
}

/// Messages with a date chip whenever the IST day changes (web buildMessageTimeline).
List<TimelineItem> buildTimeline(List<ChatMessage> messages, {DateTime? now}) {
  final items = <TimelineItem>[];
  var lastDay = '';
  for (var index = 0; index < messages.length; index++) {
    final message = messages[index];
    final date = parseServerDate(message.timestamp);
    final day = date == null ? 'unknown-$index' : istDayKey(date);
    if (day != lastDay) {
      items.add(DateItem('date-$day-$index', formatDateChip(message.timestamp, now: now)));
      lastDay = day;
    }
    items.add(MessageItem('msg-$index', message));
  }
  return items;
}

/// Meta's free 24-hour WhatsApp reply window, counted from the last customer message.
class ServiceWindow {
  const ServiceWindow({required this.open, required this.secondsRemaining});

  final bool open;
  final int secondsRemaining;
}

ServiceWindow serviceWindowFromMessages(List<ChatMessage> messages, {DateTime? now}) {
  final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
  for (var index = messages.length - 1; index >= 0; index--) {
    if (!isUserMessage(messages[index].role)) continue;
    final lastUserAt = parseServerDate(messages[index].timestamp);
    if (lastUserAt == null) continue;
    final remaining = ((lastUserAt.millisecondsSinceEpoch + const Duration(hours: 24).inMilliseconds - nowMs) / 1000)
        .floor();
    final seconds = remaining < 0 ? 0 : remaining;
    return ServiceWindow(open: seconds > 0, secondsRemaining: seconds);
  }
  return const ServiceWindow(open: false, secondsRemaining: 0);
}

String formatWindowCountdown(int secondsRemaining) {
  if (secondsRemaining <= 0) return '';
  final hours = secondsRemaining ~/ 3600;
  final minutes = (secondsRemaining % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m left';
  if (minutes > 0) return '${minutes}m left';
  return 'less than 1m left';
}

/// Newest first, like the web list.
List<ChatSession> filterAndSortChats(List<ChatSession> chats, {required String search, required StatusFilter status}) {
  final list = chats.where((session) => status.matches(session) && sessionMatchesSearch(session, search)).toList();
  list.sort((a, b) => sessionTimestamp(b).compareTo(sessionTimestamp(a)));
  return list;
}
