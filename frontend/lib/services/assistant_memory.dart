import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One remembered chat turn.
class AssistantMemoryEntry {
  final String role;
  final String content;
  final DateTime at;
  final int? sessionId;

  const AssistantMemoryEntry({
    required this.role,
    required this.content,
    required this.at,
    this.sessionId,
  });

  factory AssistantMemoryEntry.fromJson(Map<String, dynamic> json) => AssistantMemoryEntry(
        role: json['role'] as String? ?? 'assistant',
        content: json['content'] as String? ?? '',
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        sessionId: (json['session'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'role': role,
        'content': content,
        'at': at.toIso8601String(),
        'session': sessionId,
      };
}

/// Local, private memory for the ScholarAI assistant.
///
/// It keeps the running conversation id, a bounded transcript and the time of
/// the last exchange so the assistant can pick the same thread back up after
/// the app is closed, and can tell the student when a topic was last discussed.
/// The backend keeps the authoritative message history; this is only the local
/// continuity layer that survives a refresh or a restart.
class AssistantMemory {
  AssistantMemory._({SharedPreferences? prefs}) : _prefs = prefs;

  static const String _kSessionId = 'assistant.session_id';
  static const String _kTranscript = 'assistant.transcript';
  static const String _kLastActive = 'assistant.last_active';
  static const String _kTopic = 'assistant.last_topic';

  /// How many turns to keep locally. Older turns live on the server and are
  /// recalled through the backend memory block instead.
  static const int _maxEntries = 60;

  /// A conversation is resumed when it was active this recently; after that a
  /// fresh server session starts so the context window stays focused, while
  /// the recap still points at what was discussed earlier.
  static const Duration resumeWindow = Duration(hours: 12);

  final SharedPreferences? _prefs;

  int? sessionId;
  List<AssistantMemoryEntry> transcript = <AssistantMemoryEntry>[];
  DateTime? lastActive;
  String lastTopic = '';

  static Future<AssistantMemory> load() async {
    final prefs = await SharedPreferences.getInstance();
    final memory = AssistantMemory._(prefs: prefs)
      ..sessionId = prefs.getInt(_kSessionId)
      ..lastActive = DateTime.tryParse(prefs.getString(_kLastActive) ?? '')
      ..lastTopic = prefs.getString(_kTopic) ?? '';

    final raw = prefs.getString(_kTranscript);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          memory.transcript = decoded
              .whereType<Map<String, dynamic>>()
              .map(AssistantMemoryEntry.fromJson)
              .where((e) => e.content.trim().isNotEmpty)
              .toList();
        }
      } catch (_) {
        memory.transcript = <AssistantMemoryEntry>[];
      }
    }
    return memory;
  }

  /// True when there is a conversation recent enough to continue.
  bool get canResume {
    final stamp = lastActive;
    if (stamp == null) return false;
    return DateTime.now().difference(stamp) < resumeWindow;
  }

  /// The session id to send, or null when a new session should be started.
  int? get resumableSessionId => canResume ? sessionId : null;

  /// A short sentence describing the previous discussion, for the "welcome
  /// back" note. Returns null on a first visit.
  String? get recap {
    final stamp = lastActive;
    if (stamp == null || transcript.isEmpty) return null;
    final topic = lastTopic.trim().isNotEmpty ? lastTopic.trim() : _firstUserMessage() ?? '';
    if (topic.isEmpty) return null;
    final clipped = topic.length > 90 ? '${topic.substring(0, 90)}…' : topic;
    return 'We last spoke ${_describeWhen(stamp)} about "$clipped". '
        'You can pick that up again, or ask something new.';
  }

  String? _firstUserMessage() {
    for (final entry in transcript) {
      if (entry.role == 'user' && entry.content.trim().isNotEmpty) return entry.content;
    }
    return null;
  }

  static String _describeWhen(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(when.year, when.month, when.day);
    final time = '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'earlier today at $time';
    if (diff == 1) return 'yesterday at $time';
    if (diff < 7) return 'on ${_weekday(when.weekday)} at $time';
    return 'on ${when.day} ${_month(when.month)} at $time';
  }

  static String _weekday(int weekday) => const <String>[
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][(weekday - 1).clamp(0, 6)];

  static String _month(int month) => const <String>[
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][(month - 1).clamp(0, 11)];

  /// Record a turn and remember it as the running topic.
  Future<void> remember(String role, String content, {int? session}) async {
    final text = content.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    final id = session ?? sessionId;
    transcript.add(AssistantMemoryEntry(role: role, content: text, at: now, sessionId: id));
    if (transcript.length > _maxEntries) {
      transcript = transcript.sublist(transcript.length - _maxEntries);
    }
    lastActive = now;
    if (role == 'user' && lastTopic.trim().isEmpty) lastTopic = text;

    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_kTranscript, jsonEncode(transcript.map((e) => e.toJson()).toList()));
    await prefs.setString(_kLastActive, now.toIso8601String());
    await prefs.setString(_kTopic, lastTopic);
    if (sessionId != null) await prefs.setInt(_kSessionId, sessionId!);
  }

  /// Bind to the server session id returned by a new conversation.
  Future<void> adoptSession(int id) async {
    if (sessionId == id) return;
    sessionId = id;
    await _prefs?.setInt(_kSessionId, id);
  }

  /// Forget everything locally. The server history is untouched.
  Future<void> clear() async {
    sessionId = null;
    transcript = <AssistantMemoryEntry>[];
    lastActive = null;
    lastTopic = '';
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.remove(_kSessionId);
    await prefs.remove(_kTranscript);
    await prefs.remove(_kLastActive);
    await prefs.remove(_kTopic);
  }
}
