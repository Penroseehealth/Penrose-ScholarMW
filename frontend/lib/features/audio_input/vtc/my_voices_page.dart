import 'package:flutter/material.dart';

import '../../../core/networking/api_client.dart';
import 'clone_controller.dart';
import 'voice_catalog.dart';
import 'voice_library_controller.dart';
import 'vtc_theme.dart';
import 'widgets/composer_widgets.dart';
import 'widgets/vtc_audio_player.dart';
import 'widgets/vtc_status_widgets.dart';

/// MY VOICES — the user's saved voice library.
///
/// Two different things live here, and the page keeps them apart because they
/// are not the same thing:
///
/// * **Trained voices** are real clones from `/speech/clones`. Someone recorded
///   a sample, consented, and the backend built a profile. These can be
///   previewed, compared against the narrator, retrained and deleted.
/// * **Saved voices** are entries in the `voice_profiles` table — engine voices
///   the user has named. The library is a *selection* layer over voices the
///   TTS engine already provides, and every entry really can be synthesized.
///
/// The default voice here is what the rest of the app speaks with, because
/// `/speech/synthesize` resolves the library default when a request does not
/// name one.
class MyVoicesPage extends StatefulWidget {
  const MyVoicesPage({
    super.key,
    required this.apiClient,
    required this.onOpenTrainingCenter,
    this.library,
    this.clones,
  });

  final ApiClient apiClient;

  /// Switches the shared workspace back to the Voice Training Center tab.
  final VoidCallback onOpenTrainingCenter;

  /// Injected in tests; production builds construct their own.
  final VoiceLibraryController? library;
  final CloneController? clones;

  @override
  State<MyVoicesPage> createState() => _MyVoicesPageState();
}

class _MyVoicesPageState extends State<MyVoicesPage> {
  late final VoiceLibraryController _library = widget.library ?? VoiceLibraryController(apiClient: widget.apiClient);

  /// Trained voices, owned separately from the saved-voice library so a failure
  /// to load one does not blank the other.
  late final CloneController _clones = widget.clones ?? CloneController(apiClient: widget.apiClient);

  /// Whether archived entries are shown. Archived rows stay in the table so a
  /// mistake is recoverable, but they are hidden by default.
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _library.addListener(_onChanged);
    _clones.addListener(_onChanged);
    _library.load();
    _clones.load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _library.removeListener(_onChanged);
    _clones.removeListener(_onChanged);
    // Only dispose a controller this widget created; an injected one is owned
    // by the caller and may outlive this page.
    if (widget.library == null) _library.dispose();
    if (widget.clones == null) _clones.dispose();
    super.dispose();
  }

  List<VoiceEntry> get _visibleEntries {
    final all = _library.entries;
    final shown = _showArchived ? all : all.where((e) => !e.isArchived).toList(growable: false);
    return shown;
  }

  @override
  Widget build(BuildContext context) {
    // GlassPanel is a BackdropFilter, not a Material, so the search field would
    // otherwise depend on an ancestor Scaffold to exist. Provide our own
    // transparent Material so this page works in any host.
    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 18),
                if (_library.actionError != null) ...[
                  VtcErrorStrip(message: _library.actionError!, onRetry: () => _library.load()),
                ],
                if (_library.previewError != null) ...[
                  VtcErrorStrip(message: _library.previewError!, onRetry: () => _library.clearPreviewError()),
                ],
                _body(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final c = _library;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('My voices', style: VtcType.sectionHeading(context)),
        const SizedBox(height: 6),
        Text(
          'Saved voices from the speech engine configured on this server. '
          'The one marked default is what Penrose speaks with everywhere.',
          style: VtcType.body(context).copyWith(fontSize: 13.5),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (!c.ttsConfigured && c.state == LibraryState.ready)
              const VtcStatusPill(text: 'TTS OFFLINE', color: VtcPalette.danger),
            if (c.state == LibraryState.ready && c.ttsConfigured) ...[
              VtcStatusPill(
                text: c.isEmpty ? 'NO VOICES YET' : '${c.entries.length} SAVED',
                color: c.isEmpty ? VtcPalette.ivoryDim : VtcPalette.success,
              ),
              const SizedBox(width: 8),
              if (c.defaultVoice.isNotEmpty)
                VtcStatusPill(text: 'DEFAULT: ${c.defaultVoice.toUpperCase()}', color: VtcPalette.electricBright),
            ],
          ],
        ),
        const SizedBox(height: 14),
        // Honest capability read-out, driven by what the backend reports rather
        // than by what the build happens to support.
        VtcNoticeStrip(
          margin: EdgeInsets.zero,
          message: c.cloningAvailable
              ? 'Trained voices are your own recordings, built by '
                  '${c.cloneProvider}. The saved voices below are the engine\'s '
                  'own, kept under names you chose.'
              : 'These are the engine\'s own voices, saved under your names. No '
                  'voice-cloning provider is configured, so there is no '
                  'trained model, fidelity score or progress to report.',
          onDismiss: () {},
        ),
      ],
    );
  }

  Widget _body() {
    final c = _library;
    switch (c.state) {
      case LibraryState.idle:
      case LibraryState.loading:
        return const _LibrarySkeleton();
      case LibraryState.failed:
        return GlassPanel(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Could not load your voices', style: VtcType.sectionHeading(context).copyWith(fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                c.loadError ?? 'Unknown error.',
                style: VtcType.body(context).copyWith(fontSize: 13, color: VtcPalette.danger),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: c.retry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        );
      case LibraryState.ready:
        return _readyBody();
    }
  }

  Widget _readyBody() {
    final c = _library;
    final visible = _visibleEntries;
    final archivedCount = c.entries.where((e) => e.isArchived).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _trainedSection(),
        const SizedBox(height: 18),
        _addCard(),
        const SizedBox(height: 18),
        Row(
          children: [
            Text('Your library', style: VtcType.sectionHeading(context).copyWith(fontSize: 18)),
            const Spacer(),
            if (archivedCount > 0)
              TextButton.icon(
                onPressed: () => setState(() => _showArchived = !_showArchived),
                icon: Icon(_showArchived ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16),
                label: Text(_showArchived ? 'Hide archived ($archivedCount)' : 'Show archived ($archivedCount)'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (c.isEmpty)
          _emptyState()
        else if (visible.isEmpty)
          GlassPanel(
            margin: EdgeInsets.zero,
            child: Text(
              'Every saved voice is archived. Show archived to restore one.',
              style: VtcType.body(context).copyWith(fontSize: 13.5),
            ),
          )
        else
          for (final entry in visible) ...[_voiceCard(entry), const SizedBox(height: 12)],
      ],
    );
  }

  Widget _emptyState() {
    return GlassPanel(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('No voices saved yet', style: VtcType.sectionHeading(context).copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            'Add one of the engine\'s voices above, or open the Voice Training '
            'Center to record a sample and transcribe it.',
            style: VtcType.body(context).copyWith(fontSize: 13.5),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: widget.onOpenTrainingCenter,
            icon: const Icon(Icons.mic_rounded, size: 18),
            label: const Text('Open Voice Training Center'),
          ),
        ],
      ),
    );
  }

  // -- trained voices --------------------------------------------------------

  /// The cloned voices, above the saved-voice library. When the provider is
  /// unavailable the section says why instead of rendering an empty list that
  /// looks like data loss.
  Widget _trainedSection() {
    final c = _clones;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Your trained voices', style: VtcType.sectionHeading(context).copyWith(fontSize: 18)),
            const Spacer(),
            if (c.available && c.voices.isNotEmpty)
              VtcStatusPill(text: '${c.voices.length} TRAINED', color: VtcPalette.success),
          ],
        ),
        const SizedBox(height: 10),
        if (c.state == CloneLoadState.loading || c.state == CloneLoadState.idle)
          const _CloneSkeleton()
        else if (c.state == CloneLoadState.failed)
          GlassPanel(
            margin: EdgeInsets.zero,
            child: Text(
              c.loadError ?? 'Could not load your trained voices.',
              style: VtcType.body(context).copyWith(fontSize: 13, color: VtcPalette.danger),
            ),
          )
        else if (!c.available)
          GlassPanel(
            margin: EdgeInsets.zero,
            child: Text(
              'Voice training is not available: no cloning provider is '
              'configured on the backend. The saved voices below still work.',
              style: VtcType.body(context).copyWith(fontSize: 13.5),
            ),
          )
        else if (!c.reachable)
          // Configured but not answering. Caught here rather than at the end of
          // a training run, when the only recourse is to record the sample
          // again.
          GlassPanel(
            margin: EdgeInsets.zero,
            child: Text(
              'Voice training is unavailable: the local voice service is not '
              'answering. Start the OpenVoice sidecar and try again. The saved '
              'voices below still work.',
              style: VtcType.body(context).copyWith(fontSize: 13.5, color: VtcPalette.danger),
            ),
          )
        else if (c.voices.isEmpty)
          GlassPanel(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('You have not trained a voice yet', style: VtcType.sectionHeading(context).copyWith(fontSize: 17)),
                const SizedBox(height: 8),
                Text(
                  'Record a sample of your own voice, confirm you own it, and '
                  'train a profile you can then speak with.',
                  style: VtcType.body(context).copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: widget.onOpenTrainingCenter,
                    icon: const Icon(Icons.mic_rounded, size: 18),
                    label: const Text('Train a voice'),
                  ),
                ),
              ],
            ),
          )
        else
          for (final v in c.voices) ...[_cloneCard(v), const SizedBox(height: 12)],
        if (c.actionError != null) ...[
          const SizedBox(height: 4),
          VtcErrorStrip(message: c.actionError!, onRetry: c.clearActionError),
        ],
        if (c.previewError != null) ...[
          const SizedBox(height: 4),
          VtcErrorStrip(message: c.previewError!, onRetry: c.clearPreviewError),
        ],
      ],
    );
  }

  Widget _cloneCard(CloneVoice voice) {
    final c = _clones;
    final preview = c.previewFor(voice.id);
    final comparison = c.comparisonFor(voice.id);
    final version = voice.currentVersion;
    final quality = version?.quality;
    final similarity = voice.similarityLabel;
    // OpenVoice measures no similarity, so this reads "Unknown" rather than 0%.
    // An unmeasured clone is not a bad clone, and showing a score the backend
    // did not compute would be a lie.
    final similarityUnknown = similarity.isEmpty || similarity.toLowerCase() == 'unknown';

    return GlassPanel(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  voice.displayName,
                  style: VtcType.sectionHeading(context).copyWith(fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              VtcStatusPill(
                text: voice.status.toUpperCase(),
                color: voice.ready
                    ? VtcPalette.success
                    : voice.failed
                        ? VtcPalette.danger
                        : VtcPalette.ivoryDim,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (voice.provider.isNotEmpty) voice.provider,
              if (voice.language.isNotEmpty) voice.language,
              if (voice.accentLabel.isNotEmpty) voice.accentLabel,
              if (voice.consentGiven) 'consent recorded',
            ].join(' · '),
            style: VtcType.body(context).copyWith(fontSize: 12.5),
          ),
          if (similarity.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              similarityUnknown
                  ? 'Similarity is not measured by '
                      '${voice.provider.isEmpty ? _clones.capability.provider : voice.provider}, '
                      'so there is no score to report. Listen to the preview '
                      'and judge for yourself.'
                  : 'Similarity: $similarity',
              style: VtcType.body(context).copyWith(fontSize: 12.5, color: VtcPalette.ivoryDim),
            ),
          ],
          if (quality != null && quality.measured) ...[
            const SizedBox(height: 6),
            Text(quality.summary, style: VtcType.body(context).copyWith(fontSize: 12.5, color: VtcPalette.ivoryDim)),
          ],
          if (voice.failed && voice.failureReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(voice.failureReason, style: VtcType.body(context).copyWith(fontSize: 12.5, color: VtcPalette.danger)),
          ],
          for (final w in (quality?.warnings ?? const <String>[])) ...[
            const SizedBox(height: 4),
            Text('· $w', style: VtcType.body(context).copyWith(fontSize: 12, color: VtcPalette.goldLight)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                icon: Icons.play_arrow_rounded,
                label: c.isPreviewing(voice.id) ? 'Rendering…' : (preview == null ? 'Preview' : 'Re-render'),
                busy: c.isPreviewing(voice.id),
                onPressed: voice.ready ? () => c.preview(voice.id) : null,
              ),
              _ActionButton(
                icon: Icons.compare_arrows_rounded,
                label: c.isComparing(voice.id) ? 'Comparing…' : 'Compare',
                busy: c.isComparing(voice.id),
                onPressed: voice.ready ? () => c.compare(voice.id) : null,
              ),
              _ActionButton(
                icon: Icons.refresh_rounded,
                label: 'Retrain',
                busy: c.isTraining(voice.id),
                onPressed: c.isTraining(voice.id) ? null : () => c.retrain(voice.id),
              ),
              _ActionButton(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                danger: true,
                onPressed: c.isTraining(voice.id) ? null : () => _promptDeleteClone(voice),
              ),
            ],
          ),
          if (preview != null) ...[
            const SizedBox(height: 14),
            VtcAudioPlayer(
              key: ValueKey('clone-preview-${voice.id}-${preview.base64.length}'),
              speech: preview,
              onRegenerate: () => c.preview(voice.id),
              onNotice: (_) {},
            ),
          ],
          if (comparison != null) ...[const SizedBox(height: 14), _comparisonBlock(comparison)],
        ],
      ),
    );
  }

  /// The A/B block: the same sentence in the clone and in the narrator voice, so
  /// the user can judge the clone against something they already know.
  Widget _comparisonBlock(VoiceComparison cmp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Same text, two voices', style: VtcType.sectionHeading(context).copyWith(fontSize: 15)),
        const SizedBox(height: 4),
        Text('"${cmp.text}"', style: VtcType.body(context).copyWith(fontSize: 12.5, fontStyle: FontStyle.italic)),
        const SizedBox(height: 10),
        Text(
          'Trained: ${cmp.clone.voice}   ·   Narrator: ${cmp.original.voice}',
          style: VtcType.body(context).copyWith(fontSize: 12, color: VtcPalette.ivoryDim),
        ),
        if (cmp.similarityUnknown) ...[
          const SizedBox(height: 4),
          Text(
            'This provider does not measure similarity, so listen and decide '
            'for yourself.',
            style: VtcType.body(context).copyWith(fontSize: 12, color: VtcPalette.ivoryDim),
          ),
        ],
        const SizedBox(height: 10),
        VtcAudioPlayer(
          key: ValueKey('cmp-clone-${cmp.voiceId}-${cmp.clone.base64.length}'),
          speech: cmp.clone,
          onRegenerate: () {},
          onNotice: (_) {},
        ),
        const SizedBox(height: 8),
        VtcAudioPlayer(
          key: ValueKey('cmp-orig-${cmp.voiceId}-${cmp.original.base64.length}'),
          speech: cmp.original,
          onRegenerate: () {},
          onNotice: (_) {},
        ),
      ],
    );
  }

  Future<void> _promptDeleteClone(CloneVoice voice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VtcPalette.navyDeep,
        title: Text(
          'Delete ${voice.displayName}?',
          style: VtcType.sectionHeading(dialogContext).copyWith(fontSize: 18),
        ),
        content: Text(
          'This permanently removes the trained profile, every version of it, '
          'and the stored sample. It cannot be undone.',
          style: VtcType.body(dialogContext).copyWith(fontSize: 13.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: VtcPalette.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _clones.remove(voice.id);
  }

  // -- add a voice -----------------------------------------------------------

  Widget _addCard() {
    final c = _library;
    final options = c.engineVoices;

    return GlassPanel(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VtcSectionHeader(
            number: '1',
            icon: Icons.library_add_rounded,
            heading: 'Add a voice',
            description: 'Pick a voice the engine provides and give it a name you will '
                'recognise. Names are yours; the voice itself is the engine\'s.',
          ),
          const SizedBox(height: 14),
          if (options.isEmpty)
            Text(
              'Every voice this engine provides is already in your library.',
              style: VtcType.body(context).copyWith(fontSize: 13),
            )
          else ...[
            _AddVoiceForm(options: options, busy: c.mutating, onAdd: _promptAdd),
          ],
          const SizedBox(height: 18),
          const GoldRule(width: double.infinity, height: 1),
          const SizedBox(height: 18),
          VtcSectionHeader(
            number: '2',
            icon: Icons.mic_rounded,
            heading: 'Create New Voice',
            description: 'Record or upload a sample in the Voice Training Center. '
                'That flow captures audio, measures quality and transcribes it '
                '— it does not produce a cloned speaker.',
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: widget.onOpenTrainingCenter,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Open Voice Training Center'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptAdd(VoiceOption option) async {
    final result = await showDialog<_VoiceFormResult>(
      context: context,
      builder: (_) => _VoiceFormDialog(
        title: 'Add ${option.label} · ${option.id}',
        initialName: option.label,
        noteLabel: 'Style note (optional)',
        noteHint: 'e.g. warm, slower narration',
        checkboxLabel: 'Make this my default voice',
        initialMakeDefault: _library.entries.isEmpty,
      ),
    );
    if (result == null) return;
    final name = result.name.trim();
    await _library.add(
      option.id,
      displayName: name.isEmpty ? null : name,
      styleNote: result.note.trim(),
      makeDefault: result.makeDefault,
    );
  }

  // -- one library row -------------------------------------------------------

  Widget _voiceCard(VoiceEntry entry) {
    final c = _library;
    final option = VoiceCatalog.describe(entry.voiceKey);
    final preview = c.previewFor(entry.id);

    return Opacity(
      opacity: entry.isArchived ? 0.6 : 1,
      child: GlassPanel(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.displayName,
                              style: VtcType.sectionHeading(context).copyWith(fontSize: 17),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (entry.isDefault) ...[
                            const SizedBox(width: 8),
                            const VtcStatusPill(text: 'DEFAULT', color: VtcPalette.goldLight),
                          ],
                          if (entry.isArchived) ...[
                            const SizedBox(width: 8),
                            const VtcStatusPill(text: 'ARCHIVED', color: VtcPalette.ivoryDim),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          entry.voiceKey,
                          if (option != null) option.regionCode,
                          if (entry.accentLabel.isNotEmpty) entry.accentLabel,
                          if (entry.styleNote.isNotEmpty) entry.styleNote,
                        ].join(' · '),
                        style: VtcType.body(context).copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionButton(
                  icon: Icons.play_arrow_rounded,
                  label: c.isPreviewing(entry.id) ? 'Rendering…' : (preview == null ? 'Preview' : 'Re-render'),
                  busy: c.isPreviewing(entry.id),
                  onPressed: () => c.preview(entry.id),
                ),
                if (!entry.isDefault && !entry.isArchived)
                  _ActionButton(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Use voice',
                    onPressed: c.isBusy(entry.id) ? null : () => c.setDefault(entry.id),
                  ),
                if (!entry.isArchived)
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Rename',
                    onPressed: c.isBusy(entry.id) ? null : () => _promptRename(entry),
                  ),
                _ActionButton(
                  icon: entry.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                  label: entry.isArchived ? 'Restore' : 'Archive',
                  onPressed: c.isBusy(entry.id) ? null : () => c.setArchived(entry.id, !entry.isArchived),
                ),
                _ActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  danger: true,
                  onPressed: c.isBusy(entry.id) ? null : () => _promptDelete(entry),
                ),
              ],
            ),
            if (preview != null) ...[
              const SizedBox(height: 14),
              VtcAudioPlayer(
                key: ValueKey('preview-${entry.id}-${preview.base64.length}'),
                speech: preview,
                onRegenerate: () => c.preview(entry.id),
                onNotice: (_) {},
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _promptRename(VoiceEntry entry) async {
    final result = await showDialog<_VoiceFormResult>(
      context: context,
      builder: (_) => _VoiceFormDialog(title: 'Rename voice', initialName: entry.displayName, confirmLabel: 'Save'),
    );
    final name = result?.name.trim() ?? '';
    if (result == null || name.isEmpty) return;
    await _library.rename(entry.id, name);
  }

  Future<void> _promptDelete(VoiceEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VtcPalette.navyDeep,
        title: Text(
          'Delete ${entry.displayName}?',
          style: VtcType.sectionHeading(dialogContext).copyWith(fontSize: 18),
        ),
        content: Text(
          'This removes the saved voice from the server. The engine still '
          'provides it, so you can add it again at any time.',
          style: VtcType.body(dialogContext).copyWith(fontSize: 13.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: VtcPalette.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _library.remove(entry.id);
  }
}

/// What a [_VoiceFormDialog] returns when confirmed.
class _VoiceFormResult {
  const _VoiceFormResult({required this.name, required this.note, required this.makeDefault});

  final String name;
  final String note;
  final bool makeDefault;
}

/// Name/note form used by both "add a voice" and "rename".
///
/// This is a stateful widget so it owns and disposes its own
/// [TextEditingController]s. Disposing them from the caller right after
/// `showDialog` returns would free them while the route is still animating out
/// and its `TextField` is still mounted.
class _VoiceFormDialog extends StatefulWidget {
  const _VoiceFormDialog({
    required this.title,
    required this.initialName,
    this.noteLabel,
    this.noteHint,
    this.checkboxLabel,
    this.initialMakeDefault = false,
    this.confirmLabel = 'Add',
  });

  final String title;
  final String initialName;
  final String? noteLabel;
  final String? noteHint;
  final String? checkboxLabel;
  final bool initialMakeDefault;
  final String confirmLabel;

  @override
  State<_VoiceFormDialog> createState() => _VoiceFormDialogState();
}

class _VoiceFormDialogState extends State<_VoiceFormDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.initialName);
  late final TextEditingController _note = TextEditingController();
  late bool _makeDefault = widget.initialMakeDefault;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VtcPalette.navyDeep,
      title: Text(widget.title, style: VtcType.sectionHeading(context).copyWith(fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('voice-form-name'),
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          if (widget.noteLabel != null) ...[
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('voice-form-note'),
              controller: _note,
              decoration: InputDecoration(labelText: widget.noteLabel, hintText: widget.noteHint),
            ),
          ],
          if (widget.checkboxLabel != null)
            CheckboxListTile(
              value: _makeDefault,
              onChanged: (v) => setState(() => _makeDefault = v ?? false),
              title: Text(widget.checkboxLabel!),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(_VoiceFormResult(name: _name.text, note: _note.text, makeDefault: _makeDefault)),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? VtcPalette.danger : VtcPalette.ivory;
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 12.5),
      ),
    );
  }
}

class _AddVoiceForm extends StatefulWidget {
  const _AddVoiceForm({required this.options, required this.onAdd, this.busy = false});

  final List<VoiceOption> options;
  final ValueChanged<VoiceOption> onAdd;
  final bool busy;

  @override
  State<_AddVoiceForm> createState() => _AddVoiceFormState();
}

class _AddVoiceFormState extends State<_AddVoiceForm> {
  String _query = '';
  String? _selected;

  List<VoiceOption> get _filtered {
    final q = _query.trim().toLowerCase();
    final all = widget.options;
    if (q.isEmpty) return all;
    return all
        .where(
          (o) =>
              o.id.toLowerCase().contains(q) ||
              o.label.toLowerCase().contains(q) ||
              o.regionCode.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final options = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search engine voices',
            prefixIcon: Icon(Icons.search_rounded, size: 18),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 12),
        if (options.isEmpty)
          Text('No engine voice matches "$_query".', style: VtcType.body(context).copyWith(fontSize: 13))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text('${option.label} · ${option.id}'),
                  selected: _selected == option.id,
                  onSelected: (_) => setState(() => _selected = option.id),
                ),
            ],
          ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: widget.busy || _selected == null || options.every((o) => o.id != _selected)
                ? null
                : () {
                    final chosen = options.firstWhere((o) => o.id == _selected);
                    widget.onAdd(chosen);
                    setState(() => _selected = null);
                  },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add to my voices'),
          ),
        ),
      ],
    );
  }
}

class _CloneSkeleton extends StatelessWidget {
  const _CloneSkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(height: 14),
          Text('Loading your trained voices…', style: VtcType.body(context).copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

class _LibrarySkeleton extends StatelessWidget {
  const _LibrarySkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(height: 14),
          Text('Loading your voices from the server…', style: VtcType.body(context).copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}
