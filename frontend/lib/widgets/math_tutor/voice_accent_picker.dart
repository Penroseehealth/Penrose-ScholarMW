import 'package:flutter/material.dart';

import '../../services/voice_catalog_service.dart';

/// Accent + gender selector for the tutor narration.
///
/// Each option previews the real server voice, so a student can hear an accent
/// before committing to it instead of guessing from a name.
class VoiceAccentPicker extends StatelessWidget {
  final VoiceCatalogService catalog;
  final String selectedVoiceId;
  final ValueChanged<String> onSelected;
  final ValueChanged<String>? onPreview;

  const VoiceAccentPicker({
    super.key,
    required this.catalog,
    required this.selectedVoiceId,
    required this.onSelected,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = catalog.voiceForId(selectedVoiceId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.record_voice_over_rounded, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text('Tutor voice', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            if (!catalog.loadedFromApi)
              Tooltip(
                message: 'Using the built-in voice list',
                child: Icon(Icons.cloud_off_rounded, size: 14, color: scheme.outline),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          selected.description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        for (final accent in VoiceCatalogService.accents) ...<Widget>[
          Text(accent, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary)),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              for (final gender in VoiceCatalogService.genders)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: gender == VoiceCatalogService.genders.first ? 8 : 0),
                    child: _VoiceTile(
                      voice: catalog.forAccentGender(accent, gender),
                      selected: selected.id == VoiceCatalogService.idFor(accent, gender),
                      onTap: () => onSelected(VoiceCatalogService.idFor(accent, gender)),
                      onPreview: onPreview == null ? null : () => onPreview!(VoiceCatalogService.idFor(accent, gender)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({
    required this.voice,
    required this.selected,
    required this.onTap,
    this.onPreview,
  });

  final TutorVoice voice;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withAlpha(28) : scheme.surfaceContainerHighest.withAlpha(90),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                voice.isMale ? Icons.person_rounded : Icons.person_outline_rounded,
                size: 16,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${voice.accent} ${voice.gender}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected ? scheme.primary : scheme.onSurface,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onPreview != null)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onPreview,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(Icons.play_circle_outline_rounded, size: 17, color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
