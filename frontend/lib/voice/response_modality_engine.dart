/// Determines how a voice response should be delivered:
/// text only, audio only, visual only, or combined (audio + text + visual).
class ResponseModalityEngine {
  ResponseModalityEngine._();

  /// Classify the best response modality based on user request and content.
  static ResponseModality classify({
    required String userText,
    String aiText = '',
    String subject = '',
  }) {
    final lower = userText.toLowerCase();

    // Explicit audio requests
    const audioKeywords = [
      'speak',
      'say it',
      'tell me verbally',
      'read aloud',
      'voice',
      'audio',
      'say that',
      'repeat',
    ];
    if (audioKeywords.any((kw) => lower.contains(kw))) {
      return ResponseModality.audio;
    }

    // Explicit text requests
    const textKeywords = [
      'just text',
      "don't speak",
      'write it',
      'text only',
      'show me the text',
      'display',
    ];
    if (textKeywords.any((kw) => lower.contains(kw))) {
      return ResponseModality.text;
    }

    // Visual requests
    const visualKeywords = [
      'show',
      'diagram',
      'draw',
      'visual',
      'chart',
      'graph',
      'picture',
      'illustration',
      'plot',
    ];
    if (visualKeywords.any((kw) => lower.contains(kw))) {
      return ResponseModality.visual;
    }

    // Content-based classification
    if (aiText.isNotEmpty) {
      final hasMath = RegExp(r'[x²³⁴⁵⁶⁷⁸⁹⁰¹∑∫√Δπ∞]').hasMatch(aiText);
      final hasChemical = RegExp(r'[A-Z][a-z]?\d|H₂O|CO₂|NaCl').hasMatch(aiText);
      final hasTable = aiText.contains('|') && aiText.contains('\n');

      if (hasTable || (hasMath && subject == 'mathematics')) {
        return ResponseModality.combined;
      }
      if (hasChemical && subject == 'chemistry') {
        return ResponseModality.combined;
      }
    }

    // Default for voice conversations: combined (audio + text)
    return ResponseModality.combined;
  }
}

/// Response delivery modality.
enum ResponseModality {
  text,
  audio,
  visual,
  combined,
}
