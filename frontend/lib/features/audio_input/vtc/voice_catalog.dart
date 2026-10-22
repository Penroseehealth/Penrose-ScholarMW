/// Configuration-driven voice catalogue for the Voice Training Center.
///
/// The set of selectable voices is **not** hard-coded in the UI: it is whatever
/// `/speech/status` reports in `tts_voices` for the engine actually configured
/// on the backend. This file only supplies *presentation* metadata (label,
/// region, region code, gender) for the voices we recognise, so adding South
/// African, Kenyan, Nigerian, New Zealand, Singapore English or Chichewa later
/// is a data change and never a component change.
library;

/// One selectable accent/voice row in the selector.
class VoiceOption {
  const VoiceOption({
    required this.id,
    required this.label,
    required this.region,
    required this.regionCode,
    required this.gender,
    this.language = 'English',
    this.note,
    this.cloneId,
  });

  /// The engine voice id that is sent to `/speech/synthesize`.
  ///
  /// For a trained voice this is a selector-local key (`clone:<id>`) rather than
  /// something the engine understands: `/speech/synthesize` addresses a clone by
  /// [`cloneId`], so the two must not be confused when building the request.
  final String id;

  /// Set when this option is one of the user's trained voices. Such an option is
  /// sent as `voice_id`, which the backend resolves through MY VOICES; the
  /// engine's fixed `voice` list cannot name it.
  final int? cloneId;

  /// Whether this option is a trained voice rather than an engine voice.
  bool get isTrained => cloneId != null;

  /// Primary text, e.g. "US English (Male)".
  final String label;

  /// Region text, e.g. "United States".
  final String region;

  /// ISO 3166-1 alpha-2 region code, e.g. "US", "GB", "SA".
  ///
  /// Deliberately not a flag emoji: Flutter web's bundled font (Roboto) has no
  /// regional-indicator glyphs, so emoji flags render as tofu boxes offline and
  /// the engine logs a "Could not find a set of Noto fonts" warning.
  final String regionCode;

  /// "Male" / "Female" badge text.
  final String gender;

  final String language;

  /// Optional short descriptor shown under the label.
  final String? note;

  String get searchHaystack => '$label $region $regionCode $id $language $gender '
          '${note ?? ''} ${isTrained ? 'trained my voice clone' : ''}'
      .toLowerCase();
}

/// Presentation metadata for the voices the configured engine exposes.
///
/// Keys are engine voice ids. Anything the backend reports that is missing
/// here still appears in the selector (see [VoiceCatalog.resolve]) so the UI
/// never hides a voice the user can actually use.
class VoiceCatalog {
  VoiceCatalog._();

  static const List<VoiceOption> _known = <VoiceOption>[
    // English — canopylabs/orpheus-v1-english
    VoiceOption(
      id: 'austin',
      label: 'US English (Male)',
      region: 'United States',
      regionCode: 'US',
      gender: 'Male',
      note: 'Warm, grounded narrator',
    ),
    VoiceOption(
      id: 'troy',
      label: 'US English (Male)',
      region: 'United States',
      regionCode: 'US',
      gender: 'Male',
      note: 'Clear and conversational',
    ),
    VoiceOption(
      id: 'diana',
      label: 'US English (Female)',
      region: 'United States',
      regionCode: 'US',
      gender: 'Female',
      note: 'Bright, presentation-ready',
    ),
    VoiceOption(
      id: 'autumn',
      label: 'US English (Female)',
      region: 'United States',
      regionCode: 'US',
      gender: 'Female',
      note: 'Soft, reflective',
    ),
    VoiceOption(
      id: 'hannah',
      label: 'US English (Female)',
      region: 'United States',
      regionCode: 'US',
      gender: 'Female',
      note: 'Neutral and even-tempered',
    ),
    VoiceOption(
      id: 'daniel',
      label: 'British English (Male)',
      region: 'United Kingdom',
      regionCode: 'GB',
      gender: 'Male',
      note: 'Measured, academic',
    ),

    // Arabic (Saudi) — canopylabs/orpheus-arabic-saudi — removed from the
    // product and dropped here, so the selector cannot offer a voice the
    // backend no longer accepts. Add voices back only when the engine
    // advertises them in `/speech/status`.

    // Future additions go here — no component changes required.
    // VoiceOption(id: 'za', label: 'South African English (Female)', ...),
    // VoiceOption(id: 'ke', label: 'Kenyan English (Male)', ...),
    // VoiceOption(id: 'ng', label: 'Nigerian English (Male)', ...),
    // VoiceOption(id: 'chichewa', label: 'Chichewa (Female)', language: 'Chichewa', ...),
  ];

  /// Builds the selector list from the engine's advertised voice ids.
  ///
  /// Unrecognised ids are surfaced with a neutral label rather than dropped, so
  /// the selector always reflects the true backend capability set.
  static List<VoiceOption> resolve(List<String> engineVoices, {String defaultVoice = 'hannah'}) {
    final byId = <String, VoiceOption>{for (final option in _known) option.id: option};
    final options = <VoiceOption>[];
    for (final id in engineVoices) {
      final known = byId[id];
      options.add(
        known ?? VoiceOption(id: id, label: _titleCase(id), region: 'Engine voice', regionCode: 'GEN', gender: '—'),
      );
    }
    if (options.isEmpty) {
      options.add(
        VoiceOption(id: defaultVoice, label: 'Default voice', region: 'Engine default', regionCode: 'GEN', gender: '—'),
      );
    }
    return options;
  }

  /// Builds the selector row for one of the user's trained voices.
  ///
  /// Takes plain values rather than a [CloneVoice] so this presentation layer
  /// stays free of a dependency on the cloning controller. The selector-local
  /// [VoiceOption.id] is derived from the clone id; the authoritative reference
  /// is [VoiceOption.cloneId], which is what synthesis is sent.
  static VoiceOption trained({
    required int cloneId,
    required String displayName,
    String language = '',
    String accent = '',
  }) {
    final name = displayName.trim().isEmpty ? 'Trained voice $cloneId' : displayName.trim();
    final detail = <String>[
      if (accent.trim().isNotEmpty) accent.trim(),
      if (language.trim().isNotEmpty) language.trim(),
    ].join(' · ');
    return VoiceOption(
      id: 'clone:$cloneId',
      label: name,
      region: 'Your trained voice',
      regionCode: 'MYV',
      gender: '—',
      language: language.trim().isEmpty ? 'English' : language.trim(),
      note: detail.isEmpty ? 'Trained in Voice Library' : detail,
      cloneId: cloneId,
    );
  }

  /// Presentation metadata for a single engine voice id, or null when the
  /// catalogue has never heard of it. Lets an already-added library entry show
  /// the same region/gender metadata the training centre shows.
  static VoiceOption? describe(String voiceKey) {
    for (final option in _known) {
      if (option.id == voiceKey) return option;
    }
    return null;
  }

  /// Case/filter helper shared by the search field.
  static List<VoiceOption> filter(List<VoiceOption> options, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return options;
    return options.where((o) => o.searchHaystack.contains(q)).toList(growable: false);
  }

  /// Turns an engine id such as `ke_nairobi` into readable display text.
  ///
  /// Deliberately regex-light: a malformed pattern here would break voice
  /// loading for the whole page, so the split is built from a raw literal.
  static String _titleCase(String id) {
    if (id.isEmpty) return id;
    return id
        .split(RegExp(r'[_ -]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}
