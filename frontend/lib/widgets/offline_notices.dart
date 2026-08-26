import 'dart:math';

/// 20 student-friendly offline notices shown when AI services are unreachable.
class OfflineNotices {
  OfflineNotices._();

  static const List<String> _messages = [
    'AI services are currently offline. You can still access all your saved notes and courses.',
    'Connection lost. Your learning materials remain available offline.',
    'ScholarAI is resting for now. Browse your courses, notes, and saved content.',
    'No internet? No problem. All syllabus content and downloaded materials are accessible.',
    'AI is offline. Your pending questions will be sent automatically when connection returns.',
    'Cloud services are unreachable. Your local progress and notes are safe.',
    'Offline mode activated. Continue learning with your saved resources.',
    'AI tutors are taking a break. Your flashcards, notes, and courses are still here.',
    'Network unavailable. All offline content remains fully accessible.',
    'ScholarAI temporarily unavailable. Your study progress is saved locally.',
    'Internet connection lost. Don\'t worry — your work is being saved.',
    'AI features need internet. You can review notes, browse courses, and track progress.',
    'Cloud services offline. Your pending questions will be queued for when we reconnect.',
    'No connection detected. Your saved notes and practice tests are available offline.',
    'ScholarAI is offline. Downloaded syllabus content and notes are fully accessible.',
    'AI assistants are unreachable. Continue studying with your local materials.',
    'Connection interrupted. Your progress is saved. AI will resume when back online.',
    'Offline mode. All saved learning materials, notes, and progress are available.',
    'AI services temporarily down. Your work is safe — pending requests will retry automatically.',
    'Network issue detected. ScholarAI will resume when connection is restored.',
  ];

  static final Random _rng = Random();

  /// Returns a random offline notice message.
  static String random() => _messages[_rng.nextInt(_messages.length)];

  /// Returns the nth offline notice (for deterministic display).
  static String byIndex(int index) => _messages[index % _messages.length];

  /// Returns all offline notice messages.
  static List<String> get all => List.unmodifiable(_messages);
}
