import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';
import '../services/voice_catalog_service.dart';
import '../voice/tts_service.dart';
import '../voice/voice_session_manager.dart';
import 'voice_clone_manager.dart';

class VoiceTrainingCenter extends StatefulWidget {
  final String selectedVoiceId;
  final void Function(String) onVoiceSelected;
  final double playbackSpeed;
  final void Function(double) onSpeedChanged;
  final bool autoRead;
  final void Function(bool) onAutoReadChanged;

  const VoiceTrainingCenter({
    super.key,
    required this.selectedVoiceId,
    required this.onVoiceSelected,
    this.playbackSpeed = 1.0,
    required this.onSpeedChanged,
    this.autoRead = false,
    required this.onAutoReadChanged,
  });

  @override
  State<VoiceTrainingCenter> createState() => _VoiceTrainingCenterState();
}

class _VoiceTrainingCenterState extends State<VoiceTrainingCenter> {
  final VoiceCatalogService _catalog = VoiceCatalogService();
  final VoiceSessionManager _session = VoiceSessionManager();
  late final PenroseTtsService _tts = PenroseTtsService(session: _session);

  String? _previewingId;

  @override
  void initState() {
    super.initState();
    _tts.initialize();
    _loadCatalog();
  }

  @override
  void dispose() {
    _tts.stop();
    _tts.dispose();
    _session.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    await _catalog.load();
    if (!mounted) return;
    setState(() {});
  }

  TutorVoice get _selected => _catalog.voiceForId(widget.selectedVoiceId);

  Future<void> _select(TutorVoice voice) async {
    widget.onVoiceSelected(voice.id);
    await VoiceCatalogService.savePreferredVoiceId(voice.id);
    if (mounted) setState(() {});
  }

  Future<void> _preview(TutorVoice voice) async {
    if (_previewingId != null) return;
    setState(() => _previewingId = voice.id);
    _tts.voiceId = voice.id;
    try {
      await _tts.speak(
        voice.previewText.isNotEmpty
            ? voice.previewText
            : "Hello, I'm your ScholarAI tutor. Let's work through this together.",
        lang: voice.locale,
      );
    } finally {
      if (mounted) setState(() => _previewingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Drawer(
        backgroundColor: context.colors.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Divider(color: context.colors.border, height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Default Voice'),
                      const SizedBox(height: 8),
                      _buildVoicePreview(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Playback Speed'),
                      const SizedBox(height: 8),
                      _buildSpeedSelector(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Auto-Read'),
                      const SizedBox(height: 8),
                      _buildAutoReadToggle(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('TTS Language'),
                      const SizedBox(height: 8),
                      _buildLanguageSelector(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Voice Cloning'),
                      const SizedBox(height: 8),
                      _buildCloneSection(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildHeader() => const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.record_voice_over_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice Training Center',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Manage your voice settings',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildSectionTitle(String title) => Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted.withValues(alpha: 0.8),
          letterSpacing: 1.2,
        ),
      );

  Widget _buildVoicePreview() {
    final voice = _selected;
    return GestureDetector(
      onTap: () => _openVoicePicker(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.volume_up_rounded, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voice.label,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                  Text(
                    '${voice.accent} · ${voice.isMale ? 'Male' : 'Female'}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: _previewingId == null ? () => _preview(voice) : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _previewingId == voice.id
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_circle_outline_rounded, size: 22, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _openVoicePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Choose a voice',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: sheetContext.colors.textPrimary,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: _buildVoiceGroups(sheetContext),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildVoiceGroups(BuildContext sheetContext) {
    const order = <String>['American', 'British', 'Indian'];
    final accents = <String>{
      ...order,
      ..._catalog.voices.map((v) => v.accent),
    }.toList()
      ..sort((a, b) {
        final ai = order.indexOf(a);
        final bi = order.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });

    final widgets = <Widget>[];
    for (final accent in accents) {
      final voices = _catalog.voices.where((v) => v.accent == accent).toList();
      if (voices.isEmpty) continue;
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          accent.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: sheetContext.colors.textMuted,
          ),
        ),
      ));
      for (final voice in voices) {
        final selected = voice.id == widget.selectedVoiceId;
        widgets.add(
          ListTile(
            key: ValueKey<String>('voice-${voice.id}'),
            dense: true,
            leading: Icon(
              voice.isMale ? Icons.man_rounded : Icons.woman_rounded,
              color: selected ? AppColors.primary : sheetContext.colors.textMuted,
            ),
            title: Text(
              voice.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : sheetContext.colors.textPrimary,
              ),
            ),
            subtitle: Text(
              voice.description,
              style: TextStyle(fontSize: 11, color: sheetContext.colors.textMuted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Preview',
                  onPressed: () => _preview(voice),
                  icon: _previewingId == voice.id
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 20),
                ),
                if (selected) const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.primary),
              ],
            ),
            onTap: () async {
              await _select(voice);
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            },
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildSpeedSelector() {
    final speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: speeds.map((s) {
        final isSelected = s == widget.playbackSpeed;
        return GestureDetector(
          onTap: () {
            widget.onSpeedChanged(s);
            VoiceCatalogService.savePreferredSpeed(s);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              '${s}x',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAutoReadToggle() => GestureDetector(
        onTap: () {
          final value = !widget.autoRead;
          widget.onAutoReadChanged(value);
          VoiceCatalogService.savePreferredAutoRead(value);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                widget.autoRead ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                size: 18,
                color: widget.autoRead ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Auto-read AI answers',
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
              Switch(
                value: widget.autoRead,
                onChanged: (value) {
                  widget.onAutoReadChanged(value);
                  VoiceCatalogService.savePreferredAutoRead(value);
                },
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      );

  Widget _buildLanguageSelector() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.language_rounded, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selected.locale,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const Text(
                    'Follows the selected voice',
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildCloneSection(BuildContext context) => GestureDetector(
        onTap: () {
          Navigator.pop(context);
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => const VoiceCloneManager(),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.fingerprint_rounded, size: 18, color: context.colors.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage My Custom Voice',
                      style: TextStyle(fontSize: 13, color: context.colors.textPrimary),
                    ),
                    Text(
                      'Record, upload, and manage cloned voices',
                      style: TextStyle(fontSize: 10, color: context.colors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.textMuted),
            ],
          ),
        ),
      );
}
