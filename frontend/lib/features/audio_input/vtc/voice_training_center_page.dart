import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/networking/api_client.dart';
import 'accent_selector.dart';
import 'clone_controller.dart';
import 'my_voices_page.dart';
import 'penrose_header.dart';
import 'scenic_backdrop.dart';
import 'system_recorder_page.dart';
import 'voice_hero.dart';
import 'voice_sidebar.dart';
import 'vtc_controller.dart';
import 'vtc_theme.dart';
import 'widgets/composer_widgets.dart';
import 'widgets/voice_training_widgets.dart';
import 'widgets/vtc_audio_player.dart';
import 'widgets/vtc_status_widgets.dart';

/// The Voice Training Center workspace.
///
/// Everything on this page is driven by real backend responses:
/// * the voice list comes from `/speech/status`,
/// * audio comes from `/speech/synthesize`,
/// * the transcript comes from `/speech/transcribe`.
///
/// There is no fake training and no fake cloned voice. When the backend has a
/// cloning provider, the train action appears and posts a real sample to
/// `/speech/clones`; when it does not, the page says so plainly and the sample
/// capture and transcription still work.
class VoiceTrainingCenterPage extends StatefulWidget {
  const VoiceTrainingCenterPage({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<VoiceTrainingCenterPage> createState() => _VoiceTrainingCenterPageState();
}

class _VoiceTrainingCenterPageState extends State<VoiceTrainingCenterPage> with SingleTickerProviderStateMixin {
  late final VtcController _controller;
  late final AnimationController _pulse;

  /// Owns the training calls. Separate from [_controller] because capturing a
  /// sample and training a voice are different jobs with different failure modes.
  late final CloneController _clones;

  final TextEditingController _composer = TextEditingController();
  final TextEditingController _voiceName = TextEditingController();
  final FocusNode _composerFocus = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _consent = false;
  bool _loadingStatus = true;
  Timer? _sampleTicker;

  /// Which sidebar destination is showing. `voice_training` is the capture and
  /// synthesis workspace; `my_voices` is the saved voice library. Both are real
  /// and both read the same backend.
  String _tab = 'voice_training';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _controller = VtcController(apiClient: widget.apiClient)..addListener(_onControllerChanged);
    _clones = CloneController(apiClient: widget.apiClient)..addListener(_onControllerChanged);
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loadingStatus = true);
    await _controller.loadStatus();
    if (mounted) setState(() => _loadingStatus = false);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _stopSampleTicker();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _clones.removeListener(_onControllerChanged);
    _clones.dispose();
    _composer.dispose();
    _voiceName.dispose();
    _composerFocus.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // -- actions ---------------------------------------------------------------

  Future<void> _synthesize() => _controller.synthesize(_composer.text);

  Future<void> _uploadSample() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['webm', 'ogg', 'mp3', 'wav', 'm4a', 'flac'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = await file.xFile.readAsBytes();
    if (bytes.isEmpty) {
      _controller.setNotice('That file was empty.');
      return;
    }
    await _controller.adoptUpload(file.name, bytes);
  }

  /// Trains a clone from the captured sample. Consent is re-checked here rather
  /// than trusted from the checkbox alone, so a stale UI state cannot send
  /// someone's voice to the server without it.
  Future<void> _train() async {
    final sample = _controller.sample;
    if (sample == null) return;
    final trained = await _clones.train(
      displayName: _voiceName.text,
      bytes: sample.bytes,
      mimeType: sample.facts.mimeType,
      consent: _consent,
      durationMs: (sample.facts.durationSeconds * 1000).round(),
    );
    if (!trained) return;
    // A voice trained here must be selectable in the chat picker right away,
    // rather than only after the page is reloaded.
    await _controller.loadTrainedVoices();
    _controller.setNotice('Trained voice added to the voice list.');
  }

  // -- training panel ---------------------------------------------------------

  /// The training call, shown only when the backend really has a cloning
  /// provider. A user with no provider configured sees the sample capture and
  /// transcription, which still work, and no dead button.
  Widget? _trainPanel(VtcController c) {
    if (!c.voiceCloningAvailable) return null;
    final sample = c.sample;
    final capability = c.cloneCapability;
    final slow = capability.synthesisIsSlow;

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GoldRule(width: double.infinity, height: 1),
          const SizedBox(height: 18),
          VtcSectionHeader(
            number: '2',
            icon: Icons.auto_awesome_rounded,
            heading: 'Train your voice',
            description: 'Name this voice and train a profile from the sample above. '
                '${capability.consentText}',
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('train-voice-name'),
            controller: _voiceName,
            decoration: const InputDecoration(labelText: 'Voice name', hintText: 'e.g. My narration voice'),
          ),
          const SizedBox(height: 12),
          if (capability.hasUnavailableModels)
            VtcNoticeStrip(
              margin: EdgeInsets.zero,
              message: 'This engine speaks ${capability.baseSpeakersAvailable.join(', ')} '
                  'from its own reference audio. Other accents were offered by '
                  'the API but would be spoken with '
                  '${capability.baseSpeakersAvailable.isEmpty ? 'the default voice' : 'en-us'}, '
                  'so they are not listed as choices.',
            ),
          if (slow)
            VtcNoticeStrip(
              margin: EdgeInsets.zero,
              message: 'Speech from this voice runs on your own CPU, so a preview '
                  'can take a minute. That is expected, not a hang.',
              onDismiss: () {},
            ),
          if (slow) const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('train-submit'),
              onPressed: sample == null || _clones.training || !_consent ? null : _train,
              icon: _clones.training
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                sample == null
                    ? 'Record a sample first'
                    : _clones.training
                        ? 'Training…'
                        : 'Train this voice',
              ),
            ),
          ),
          if (!_consent) ...[
            const SizedBox(height: 10),
            Text(
              'Tick the consent box above to enable training.',
              style: VtcType.body(context).copyWith(fontSize: 12.5, color: VtcPalette.ivoryDim),
            ),
          ],
          if (_clones.trainError != null) ...[
            const SizedBox(height: 12),
            VtcErrorStrip(message: _clones.trainError!, onRetry: _clones.clearTrainError),
          ],
          if (_clones.voices.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Trained voices (${_clones.voices.length})',
              style: VtcType.sectionHeading(context).copyWith(fontSize: 16),
            ),
            const SizedBox(height: 8),
            for (final v in _clones.voices)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${v.displayName} · ${v.status}'
                  '${v.similarityLabel.isEmpty ? '' : ' · ${v.similarityLabel}'}',
                  style: VtcType.body(context).copyWith(fontSize: 12.5),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // -- real sample playback polling -------------------------------------------

  /// Polls the audio engine so the measured clip duration and play state reach
  /// the UI. Stopped as soon as nothing is playing.
  void _startSampleTicker() {
    _sampleTicker ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      _controller.syncSampleDuration();
      if (!_controller.samplePreviewPlaying) _stopSampleTicker();
    });
  }

  void _stopSampleTicker() {
    _sampleTicker?.cancel();
    _sampleTicker = null;
  }

  Future<void> _withSampleTicker(Future<void> Function() action) async {
    _startSampleTicker();
    await action();
  }

  void _openAppDrawer() {
    // The VTC is a full-screen experience; the drawer is the escape hatch back
    // to the rest of the app.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Use the menu button to open the app drawer.')));
  }

  /// Routes a sidebar tap. Disabled destinations and `home` say plainly that
  /// they do nothing here instead of silently ignoring the tap.
  void _selectTab(VtcNavItem item) {
    if (!item.enabled) {
      _controller.setNotice(
        '"${item.label}" is not available yet — this build has no backend for '
        'it.',
      );
      return;
    }
    if (item.id == 'home') {
      _openAppDrawer();
      return;
    }
    setState(() => _tab = item.id);
  }

  bool get _showingLibrary => _tab == 'my_voices';

  /// The system-audio recorder is its own workspace: it records what the
  /// computer is playing, then transcribes and summarises that audio.
  bool get _showingRecorder => _tab == 'recorder';

  // -- pulse state -----------------------------------------------------------

  VtcPulseState get _pulseState {
    if (_controller.recording) return VtcPulseState.recording;
    if (_controller.synthesizing) return VtcPulseState.synthesizing;
    if (_controller.samplePreviewPlaying) return VtcPulseState.playing;
    return VtcPulseState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1080;
    final isCompact = width < 720;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: VtcPalette.midnight,
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: VtcPalette.navyDeep,
              child: Builder(
                builder: (drawerContext) => SafeArea(
                  child: VoiceSidebar(
                    selectedId: _tab,
                    onSelect: (item) {
                      _selectTab(item);
                      Navigator.of(drawerContext).pop();
                    },
                  ),
                ),
              ),
            ),
      body: ScenicBackdrop(
        animation: _pulse,
        child: Column(
          children: [
            PenroseHeader(
              height: isCompact ? 64 : 74,
              // Narrow screens get the real drawer; wide screens have no app
              // drawer to open, so the button explains where navigation lives.
              onMenuTap: isDesktop ? _openAppDrawer : () => _scaffoldKey.currentState?.openDrawer(),
              compact: isCompact,
            ),
            Expanded(child: isDesktop ? _desktopBody(isCompact: isCompact) : _mobileBody()),
          ],
        ),
      ),
    );
  }

  // -- desktop ---------------------------------------------------------------

  Widget _desktopBody({required bool isCompact}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The sidebar fills the column height so its flourish can sit at the
        // bottom; it must not be inside a scroll view (it uses a Spacer).
        SafeArea(
          top: false,
          right: false,
          child: VoiceSidebar(selectedId: _tab, onSelect: _selectTab),
        ),
        Expanded(
          // The library page scrolls itself; wrapping it in the training
          // page's own scroll view would nest two scrollables.
          child: _showingLibrary
              ? _myVoices()
              : _showingRecorder
                  ? _systemRecorder()
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(28, 8, 40, 48),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 940),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              VoiceHero(animation: _pulse, pulse: _pulseState),
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  'Standard voices from the configured engine',
                                  style: VtcType.body(context).copyWith(fontSize: 12.5),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _workspaceCard(),
                              const SizedBox(height: 22),
                              _footerStatements(),
                            ],
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  /// The saved voice library tab. "Create New Voice" returns here to the
  /// capture workspace rather than starting a second creation flow.
  Widget _myVoices() {
    return MyVoicesPage(
      key: const ValueKey('my-voices-tab'),
      apiClient: widget.apiClient,
      onOpenTrainingCenter: () => setState(() => _tab = 'voice_training'),
    );
  }

  /// The system-audio recorder tab, which scrolls itself.
  Widget _systemRecorder() {
    return SystemRecorderPage(
      key: const ValueKey('system-recorder-tab'),
      apiClient: widget.apiClient,
    );
  }

  // -- mobile ----------------------------------------------------------------

  Widget _mobileBody() {
    if (_showingLibrary) return _myVoices();
    if (_showingRecorder) {
      return Padding(
        padding: const EdgeInsets.only(left: 8, right: 8),
        child: _systemRecorder(),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VoiceHero(animation: _pulse, pulse: _pulseState),
          const SizedBox(height: 4),
          _workspaceCard(),
          const SizedBox(height: 20),
          _footerStatements(),
        ],
      ),
    );
  }

  // -- the central workflow card --------------------------------------------

  Widget _workspaceCard() {
    final c = _controller;

    return GlassPanel(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('Create natural speech', style: VtcType.sectionHeading(context).copyWith(fontSize: 20)),
                ),
                if (_loadingStatus)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                else if (!c.ttsConfigured)
                  VtcStatusPill(text: 'TTS OFFLINE', color: VtcPalette.danger)
                else
                  VtcStatusPill(text: '${c.voices.length} VOICES', color: VtcPalette.success),
              ],
            ),
          ),
          if (c.statusError != null) VtcErrorStrip(message: c.statusError!),
          if (_controller.notice != null)
            VtcNoticeStrip(message: _controller.notice!, onDismiss: _controller.clearNotice),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1 — text
                VtcSectionHeader(
                  number: '1',
                  icon: Icons.edit_note_rounded,
                  heading: 'Enter your text',
                  description: 'Type what you want to hear. Punctuation and line breaks '
                      'shape the pacing.',
                ),
                const SizedBox(height: 12),
                TextComposer(controller: _composer, onChanged: (_) => setState(() {}), enabled: c.ttsConfigured),
                const SizedBox(height: 22),

                // 2 — voice
                VtcSectionHeader(
                  number: '2',
                  icon: Icons.record_voice_over_rounded,
                  heading: 'Choose a voice',
                  description: 'Every accent below is provided by the speech engine '
                      'configured on this server.',
                ),
                const SizedBox(height: 12),
                if (c.voices.isEmpty && _loadingStatus)
                  const _SkeletonSelector()
                else
                  AccentSelector(
                    options: c.voices,
                    selected: c.selectedVoice,
                    enabled: c.ttsConfigured,
                    onChanged: c.selectVoice,
                  ),
                const SizedBox(height: 14),
                if (!c.ttsConfigured)
                  Text(
                    'The backend reported no configured TTS provider, so '
                    'synthesis is disabled. Set the provider credentials on the '
                    'server to enable generation.',
                    style: VtcType.body(context).copyWith(fontSize: 13, color: VtcPalette.danger),
                  ),
                const SizedBox(height: 20),

                // generate
                SynthesisButton(
                  onPressed: c.ttsConfigured && _composer.text.trim().isNotEmpty ? _synthesize : null,
                  busy: c.synthesizing,
                ),
                if (c.synthesisError != null) ...[
                  const SizedBox(height: 12),
                  VtcErrorStrip(message: c.synthesisError!),
                ],
                const SizedBox(height: 18),

                // result
                if (c.speech != null && c.synthesis == SynthesisState.ready)
                  VtcAudioPlayer(speech: c.speech!, onRegenerate: _synthesize, onNotice: _controller.setNotice),

                const SizedBox(height: 6),
                const ProTipCard(
                  title: 'Pro tip',
                  body: 'One or two sentences per paragraph gives the most natural '
                      'delivery. A full stop unlocks a longer pause; a comma only '
                      'briefens it.',
                ),
                const SizedBox(height: 26),
                const GoldRule(width: double.infinity, height: 1),
                const SizedBox(height: 24),

                // your own voice — real pipeline, honest status
                _sampleSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sampleSection() {
    final c = _controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VtcSectionHeader(
          number: '3',
          icon: Icons.mic_rounded,
          heading: 'Record your own voice',
          description: c.voiceCloningAvailable
              ? 'Record or upload a sample, confirm you own the voice, and '
                  'train a profile from it. Transcription and quality analysis '
                  'run on every sample you capture.'
              : 'Capture a sample so the speech engine can analyse and transcribe '
                  'it. This is real transcription — no cloned voice profile is '
                  'created.',
        ),
        const SizedBox(height: 14),
        VoiceTrainingStatus(
          ttsConfigured: c.ttsConfigured,
          sttConfigured: c.sttConfigured,
          ttsProvider: c.ttsProvider,
          ttsModel: c.ttsModel,
          sttProvider: c.sttProvider,
          sttModel: c.sttModel,
          cloningAvailable: c.voiceCloningAvailable,
          cloneProvider: c.cloneCapability.provider,
        ),
        const SizedBox(height: 18),
        VoiceTrainingConsent(accepted: _consent, onChanged: (v) => setState(() => _consent = v)),
        const SizedBox(height: 16),
        VoiceRecorder(
          stage: c.stage,
          recording: c.recording,
          consentGiven: _consent,
          isPreviewPlaying: c.samplePreviewPlaying,
          recordError: c.recordError,
          busy: c.stage == SampleStage.transcribing,
          onStart: () => _withSampleTicker(c.startRecording),
          onStop: () => _withSampleTicker(c.stopRecording),
          onCancel: () {
            c.deleteSample();
            _stopSampleTicker();
          },
          onReplay: () {
            c.toggleSamplePreview();
            _startSampleTicker();
          },
          onPauseToggle: () {
            c.toggleSamplePreview();
            _startSampleTicker();
          },
          onUpload: _uploadSample,
        ),
        if (c.stage == SampleStage.captured ||
            c.stage == SampleStage.transcribing ||
            c.stage == SampleStage.ready ||
            c.stage == SampleStage.failed) ...[
          const SizedBox(height: 16),
          TrainingProgress(stage: c.stage),
        ],
        if (c.sampleError != null) ...[const SizedBox(height: 12), VtcErrorStrip(message: c.sampleError!)],
        if (c.sample != null && c.stage == SampleStage.ready) ...[
          const SizedBox(height: 16),
          AudioQualityFeedback(sample: c.sample!),
        ],
        if (_trainPanel(c) case final panel?) ...[panel],
      ],
    );
  }

  Widget _footerStatements() {
    return Column(
      children: [
        Text(
          '"Authentic voices for every Malawian story."',
          textAlign: TextAlign.center,
          style: VtcType.flourish(context).copyWith(fontSize: 14),
        ),
        const SizedBox(height: 6),
        Text(
          'Crafted for Africa · Powered by Penrose',
          textAlign: TextAlign.center,
          style: VtcType.body(context).copyWith(fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        Text(
          'Module audio_input · /audio-input',
          textAlign: TextAlign.center,
          style: VtcType.body(context).copyWith(fontSize: 11.5),
        ),
      ],
    );
  }
}

class _SkeletonSelector extends StatelessWidget {
  const _SkeletonSelector();

  @override
  Widget build(BuildContext context) => Container(
        height: 62,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: VtcPalette.ivory.withValues(alpha: 0.14)),
        ),
        alignment: Alignment.center,
        child: Text('Loading voices from the engine…', style: VtcType.body(context).copyWith(fontSize: 13)),
      );
}
