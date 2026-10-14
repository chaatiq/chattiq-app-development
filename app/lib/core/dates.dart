/// Chat timestamps in India Standard Time, matching the web inbox
/// (web/components/chat-dashboard/ChatsInbox.jsx). IST is a fixed UTC+5:30
/// with no daylight saving, so it is computed directly.
library;

const _istOffset = Duration(hours: 5, minutes: 30);
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

final _hasZone = RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$', caseSensitive: false);

/// Server timestamps without a zone are UTC (web parseDate).
DateTime? parseServerDate(String? iso) {
  if (iso == null || iso.trim().isEmpty) return null;
  final raw = iso.trim();
  final normalized = _hasZone.hasMatch(raw) ? raw : '${raw.replaceFirst(RegExp(r'\.\d+$'), '')}Z';
  return DateTime.tryParse(normalized)?.toUtc();
}

/// A UTC DateTime whose fields read as the IST wall clock.
DateTime _ist(DateTime date) => date.toUtc().add(_istOffset);

String _pad(int value) => value.toString().padLeft(2, '0');

/// IST calendar day, e.g. "2026-10-06".
String istDayKey(DateTime date) {
  final ist = _ist(date);
  return '${ist.year}-${_pad(ist.month)}-${_pad(ist.day)}';
}

/// e.g. "03:30 pm" (web: en-IN, 2-digit hour, 12-hour clock).
String formatTime(String? iso) {
  final date = parseServerDate(iso);
  if (date == null) return '';
  final ist = _ist(date);
  final hour12 = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
  return '${_pad(hour12)}:${_pad(ist.minute)} ${ist.hour < 12 ? 'am' : 'pm'}';
}

/// e.g. "05 Oct".
String formatShortDate(String? iso) {
  final date = parseServerDate(iso);
  if (date == null) return '';
  final ist = _ist(date);
  return '${_pad(ist.day)} ${_months[ist.month - 1]}';
}

enum _RelativeDay { today, yesterday }

_RelativeDay? _relativeDay(DateTime date, DateTime now) {
  final key = istDayKey(date);
  if (key == istDayKey(now)) return _RelativeDay.today;
  if (key == istDayKey(now.subtract(const Duration(days: 1)))) return _RelativeDay.yesterday;
  return null;
}

/// WhatsApp-style list time: the time today, "Yesterday", or a short date.
String formatChatListTime(String? iso, {DateTime? now}) {
  final date = parseServerDate(iso);
  if (date == null) return '';
  switch (_relativeDay(date, now ?? DateTime.now())) {
    case _RelativeDay.today:
      return formatTime(iso);
    case _RelativeDay.yesterday:
      return 'Yesterday';
    case null:
      return formatShortDate(iso);
  }
}

/// Date chip between messages: "Today", "Yesterday", or e.g. "Mon, 5 Oct 2026".
String formatDateChip(String? iso, {DateTime? now}) {
  final date = parseServerDate(iso);
  if (date == null) return 'Earlier';
  switch (_relativeDay(date, now ?? DateTime.now())) {
    case _RelativeDay.today:
      return 'Today';
    case _RelativeDay.yesterday:
      return 'Yesterday';
    case null:
      final ist = _ist(date);
      return '${_weekdays[ist.weekday - 1]}, ${ist.day} ${_months[ist.month - 1]} ${ist.year}';
  }
}
