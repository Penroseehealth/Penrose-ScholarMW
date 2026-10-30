import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/networking/api_client.dart';
import '../vtc_theme.dart';
import 'capture_engine.dart';
import 'virtual_recording_controller.dart';
import 'widgets/virtual_widgets.dart';

/// Virtual Recording workspace.
///
/// The three-column desktop layout is sidebar (from the VCT shell), live
/// workspace and this page's right control panel. Every status shown here is
/// measured or reported by the browser; nothing is simulated.
class VirtualRecordingPage extends StatefulWidget {
  const VirtualRecordingPage({
    super.key,
    required this.apiClient,
    this.controller,
    this.onOpenLibrary,
  });

  final ApiClient apiClient;

  /// Optional controller owned by the shell. Passing one keeps a live capture
  /// running when the user switches VCT tabs; the shell disposes it.
  final VirtualRecordingController? controller;

  /// Opens the shared Recordings library.
  final VoidCallback? onOpenLibrary;

  @override
  State<VirtualRecordingPage> createState() => _VirtualRecordingPageState();
}

class _VirtualRecordingPageState extends State<VirtualRecordingPage> {
  late final VirtualRecordingController _controller =
      widget.controller ?? VirtualRecordingController(apiClient: widget.apiClient);
  late final bool _ownsController = widget.controller == null;

  final TextEditingController _label = TextEditingController();
  bool _labelEdited = false;
  int _panelTab = 0;
  CapturePreview _previewChoice = CapturePreview.screen;

  @override
  void initState() {
    super.initState();
    _label.addListener(_onLabelChanged);
    _controller.initialize();
  }

  void _onLabelChanged() {
    if (_label.text.trim().isEmpty) return;
    _labelEdited = true;
  }

  @override
  void dispose() {
    _label.removeListener(_onLabelChanged);
    _label.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  // -- state helpers --------------------------------------------------------

  SourceState get _micState => _controller.stateOf(CaptureSourceKind.microphone);
  SourceState get _cameraState => _controller.stateOf(CaptureSourceKind.camera);
  SourceState get _screenState => _controller.stateOf(CaptureSourceKind.screen);
  SourceState get _systemState => _controller.stateOf(CaptureSourceKind.systemAudio);

  CapturePreview? get _activePreview {
    final bool screen = _controller.screenShared;
    final bool camera = _controller.cameraRequested;
    if (screen && camera) return _previewChoice;
    if (screen) return CapturePreview.screen;
    if (camera) return CapturePreview.camera;
    return null;
  }

  String get _phaseLabel {
    switch (_controller.phase) {
      case VirtualRecordingPhase.unsupported:
        return 'Unsupported browser';
      case VirtualRecordingPhase.idle:
        return 'Idle';
      case VirtualRecordingPhase.ready:
        return 'Ready';
      case VirtualRecordingPhase.connecting:
        return 'Connecting…';
      case VirtualRecordingPhase.recording:
        return 'Recording';
      case VirtualRecordingPhase.paused:
        return 'Paused';
      case VirtualRecordingPhase.finalizing:
        return 'Finishing file…';
      case VirtualRecordingPhase.saving:
        return 'Saving to Recordings…';
      case VirtualRecordingPhase.saved:
        return 'Saved';
      case VirtualRecordingPhase.failed:
        return 'Needs attention';
    }
  }

  Color get _phaseColor {
    switch (_controller.phase) {
      case VirtualRecordingPhase.recording:
        return VtcPalette.recording;
      case VirtualRecordingPhase.paused:
        return VtcPalette.warning;
      case VirtualRecordingPhase.ready:
      case VirtualRecordingPhase.saved:
        return VtcPalette.successBright;
      case VirtualRecordingPhase.saving:
      case VirtualRecordingPhase.connecting:
      case VirtualRecordingPhase.finalizing:
        return VtcPalette.info;
      case VirtualRecordingPhase.failed:
      case VirtualRecordingPhase.unsupported:
        return VtcPalette.error;
      case VirtualRecordingPhase.idle:
        return VtcPalette.disabled;
    }
  }

  IconData get _phaseIcon {
    switch (_controller.phase) {
      case VirtualRecordingPhase.recording:
        return Icons.fiber_manual_record;
      case VirtualRecordingPhase.paused:
        return Icons.pause_circle_outline;
      case VirtualRecordingPhase.saved:
        return Icons.check_circle_outline;
      case VirtualRecordingPhase.saving:
      case VirtualRecordingPhase.finalizing:
        return Icons.sync;
      case VirtualRecordingPhase.failed:
      case VirtualRecordingPhase.unsupported:
        return Icons.error_outline;
      case VirtualRecordingPhase.ready:
        return Icons.sensors;
      case VirtualRecordingPhase.connecting:
        return Icons.sync;
      case VirtualRecordingPhase.idle:
        return Icons.radio_button_unchecked;
    }
  }

  String get _selectedSourceSummary {
    final List<String> parts = <String>[
      if (_controller.microphoneRequested) 'Microphone',
      if (_controller.screenShared && _controller.engine.screenHasAudio) 'System / tab audio',
      if (_controller.screenShared) 'Screen',
      if (_controller.cameraRequested) 'Camera',
    ];
    return parts.isEmpty ? 'None selected' : parts.join(' • ');
  }

  // -- actions --------------------------------------------------------------

  Future<void> _start() async {
    await _controller.start();
    if ((_controller.isRecording || _controller.isPaused) && !_labelEdited) {
      _label.text = _controller.suggestedLabel;
      _labelEdited = false;
    }
  }

  Future<void> _toggleMic() async {
    if (_controller.isBusy) return;
    await _controller.toggleMicrophone();
  }

  Future<void> _toggleCamera() async {
    if (_controller.isBusy) return;
    await _controller.toggleCamera();
  }

  Future<void> _toggleScreen() async {
    if (_controller.isBusy) return;
    await _controller.toggleScreenShare();
  }

  Future<void> _save({bool end = false}) async {
    final bool ok = end ? await _controller.endAndSave(label: _label.text) : await _controller.save(label: _label.text);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_controller.notice ?? 'Saved to Recordings.')),
      );
    }
  }

  Future<void> _discard() async {
    final bool confirmed = await _confirm(
      title: 'Discard this capture?',
      message: 'The recorded media is deleted from this tab and cannot be recovered. The library is not affected.',
      action: 'Discard capture',
    );
    if (!confirmed) return;
    await _controller.discard();
  }

  Future<void> _resetSession() async {
    final bool confirmed = await _confirm(
      title: 'Start a new session?',
      message: 'Microphone, camera and screen sharing will be released. Any unsaved capture is discarded.',
      action: 'Release sources',
    );
    if (!confirmed) return;
    await _controller.resetSession();
    _label.clear();
    _labelEdited = false;
  }

  Future<bool> _confirm({required String title, required String message, required String action}) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: VtcPalette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: VtcPalette.border),
        ),
        title: Text(title, style: const TextStyle(color: VtcPalette.textPrimary, fontSize: 16)),
        content: Text(message, style: const TextStyle(color: VtcPalette.textSecondary, fontSize: 13, height: 1.45)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: VtcPalette.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VtcPalette.recording, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // -- layout ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _controller,
        builder: (BuildContext context, Widget? child) => LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            final bool wide = width >= 900;
            final bool compact = width < 620;
            if (wide) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _header(compact: false),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(right: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  _mediaCard(),
                                  const SizedBox(height: 12),
                                  _primaryActions(),
                                  const SizedBox(height: 12),
                                  _meetingControls(),
                                  const SizedBox(height: 12),
                                  _statusStrip(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 352,
                            child: SingleChildScrollView(child: _rightPanel()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(compact ? 12 : 22, 8, compact ? 12 : 22, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _header(compact: compact),
                  const SizedBox(height: 12),
                  _mediaCard(),
                  const SizedBox(height: 12),
                  _primaryActions(),
                  const SizedBox(height: 12),
                  _meetingControls(),
                  const SizedBox(height: 12),
                  _statusStrip(),
                  const SizedBox(height: 16),
                  _rightPanel(),
                ],
              ),
            );
          },
        ),
      );

  // -- header ---------------------------------------------------------------

  Widget _header({required bool compact}) {
    final bool live = _controller.hasLiveSource;
    final List<Widget> pills = <Widget>[
      if (!_controller.isSupported)
        const VirtualPill(
          label: 'Browser capture unsupported',
          color: VtcPalette.error,
          icon: Icons.error_outline,
        )
      else if (_controller.phase == VirtualRecordingPhase.recording)
        VirtualPill(
          label: 'RECORDING ${formatDuration(_controller.elapsed)}',
          color: VtcPalette.recording,
          icon: Icons.fiber_manual_record,
        )
      else if (_controller.phase == VirtualRecordingPhase.paused)
        const VirtualPill(label: 'PAUSED', color: VtcPalette.warning, icon: Icons.pause_circle_outline)
      else if (live)
        const VirtualPill(
          label: 'LIVE',
          color: VtcPalette.successBright,
          icon: Icons.sensors,
          gradient: VtcPalette.liveGradient,
          foreground: Color(0xFF03130F),
        )
      else
        const VirtualPill(label: 'IDLE', color: VtcPalette.disabled, icon: Icons.pause_circle_outline),
      if (_controller.phase == VirtualRecordingPhase.saving || _controller.phase == VirtualRecordingPhase.finalizing)
        const VirtualPill(label: 'WRITING FILE', color: VtcPalette.info, icon: Icons.sync),
      if (_controller.isSupported && _controller.canSave)
        const VirtualPill(label: 'UNSAVED CAPTURE', color: VtcPalette.warning, icon: Icons.save_outlined),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Virtual Recording',
                style: TextStyle(
                  color: VtcPalette.textPrimary,
                  fontSize: compact ? 19 : 23,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Capture a tab, screen, camera and microphone into the shared Recordings library.',
                style: TextStyle(color: VtcPalette.textMuted, fontSize: 11.5, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: pills,
        ),
      ],
    );
  }

  // -- live workspace -------------------------------------------------------

  Widget _mediaCard() {
    final bool recording = _controller.isRecording;
    final CapturePreview? preview = _activePreview;
    final bool both = _controller.screenShared && _controller.cameraRequested;
    final bool hasAudio = _controller.hasAudioSource;
    final Color borderColor = recording
        ? VtcPalette.recording.withValues(alpha: 0.75)
        : preview != null
            ? VtcPalette.borderActive.withValues(alpha: 0.7)
            : VtcPalette.border;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: VtcPalette.workspace,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: recording ? 1.6 : 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (recording ? VtcPalette.recording : VtcPalette.indigo).withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _previewArea(preview, hasAudio: hasAudio),
            // Readability scrims so overlays always clear contrast.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 74,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xB3040A1C), Color(0x00040A1C)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: <Widget>[
                  if (preview != null)
                    VirtualPill(
                      label: preview == CapturePreview.screen ? 'SCREEN' : 'CAMERA',
                      color: VtcPalette.cyan,
                      icon: preview == CapturePreview.screen ? Icons.desktop_windows_outlined : Icons.videocam_outlined,
                      compact: true,
                    ),
                  if (recording) ...<Widget>[
                    const SizedBox(width: 8),
                    VirtualPill(
                      label: 'REC ${formatDuration(_controller.elapsed)}',
                      color: VtcPalette.recording,
                      icon: Icons.fiber_manual_record,
                      compact: true,
                    ),
                  ],
                  const Spacer(),
                  if (both) _previewSwitch(),
                ],
              ),
            ),
            if (preview != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _controller.screenShared
                            ? (_controller.engine.screenLabel ?? 'Shared screen')
                            : 'Camera preview',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: VtcPalette.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          shadows: <Shadow>[Shadow(color: Color(0xCC000000), blurRadius: 8)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_controller.screenShared && preview == CapturePreview.screen)
                      VirtualPill(
                        label: _controller.engine.screenHasAudio ? 'TAB AUDIO' : 'NO AUDIO',
                        color: _controller.engine.screenHasAudio ? VtcPalette.successBright : VtcPalette.warning,
                        icon: _controller.engine.screenHasAudio ? Icons.volume_up_outlined : Icons.volume_off_outlined,
                        compact: true,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _previewSwitch() => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xCC040A1C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: VtcPalette.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _previewSwitchButton('Screen', CapturePreview.screen),
            _previewSwitchButton('Camera', CapturePreview.camera),
          ],
        ),
      );

  Widget _previewSwitchButton(String label, CapturePreview kind) {
    final bool selected = _previewChoice == kind;
    return InkWell(
      onTap: () => setState(() => _previewChoice = kind),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? VtcPalette.elevated : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? VtcPalette.borderActive : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? VtcPalette.textPrimary : VtcPalette.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _previewArea(CapturePreview? preview, {required bool hasAudio}) {
    if (preview != null) {
      return RepaintBoundary(child: _controller.engine.preview(preview));
    }
    if (hasAudio) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.graphic_eq, size: 40, color: VtcPalette.cyan),
              const SizedBox(height: 10),
              const Text(
                'Audio-only capture',
                style: TextStyle(color: VtcPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              const Text(
                'The microphone and system audio are being captured. Turn on the camera or share a screen to add video.',
                textAlign: TextAlign.center,
                style: TextStyle(color: VtcPalette.textMuted, fontSize: 11.5, height: 1.45),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 260,
                child: VirtualAudioMeter(
                  level: _controller.microphoneLevel,
                  colors: const <Color>[VtcPalette.successBright, VtcPalette.warning],
                  active: _controller.microphoneRequested && !_controller.microphoneMuted,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 260,
                child: VirtualAudioMeter(
                  level: _controller.systemLevel,
                  colors: const <Color>[VtcPalette.cyan, VtcPalette.successBright],
                  active: _controller.screenShared && _controller.engine.screenHasAudio,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              _controller.isSupported ? Icons.video_camera_back_outlined : Icons.browser_not_supported,
              size: 42,
              color: _controller.isSupported ? VtcPalette.info : VtcPalette.error,
            ),
            const SizedBox(height: 10),
            Text(
              _controller.isSupported ? 'Nothing is being captured yet' : 'This browser cannot capture media',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VtcPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Text(
              _controller.isSupported
                  ? 'Share a tab or screen, turn on the camera, or use the microphone. The preview is the real source the browser selected.'
                  : 'Use a current Chrome, Edge, Firefox or Safari over HTTPS or localhost. The rest of the Voice Training Center still works.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VtcPalette.textMuted, fontSize: 11.5, height: 1.45),
            ),
            if (_controller.isSupported) ...<Widget>[
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  VirtualActionButton(
                    label: _controller.screenShared ? 'Stop sharing' : 'Share screen',
                    icon: Icons.screen_share_outlined,
                    onPressed: _toggleScreen,
                    tone: VirtualButtonTone.primary,
                  ),
                  VirtualActionButton(
                    label: _controller.cameraRequested ? 'Camera off' : 'Camera',
                    icon: Icons.videocam_outlined,
                    onPressed: _toggleCamera,
                  ),
                  VirtualActionButton(
                    label: _controller.microphoneRequested ? 'Mic off' : 'Microphone',
                    icon: Icons.mic_none_outlined,
                    onPressed: _toggleMic,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -- actions --------------------------------------------------------------

  Widget _primaryActions() {
    final bool recording = _controller.isRecording;
    final bool paused = _controller.isPaused;
    final bool saving = _controller.phase == VirtualRecordingPhase.saving;
    return VirtualCard(
      title: 'Recording controls',
      icon: Icons.tune,
      trailing: VirtualPill(
        label: _phaseLabel,
        color: _phaseColor,
        icon: _phaseIcon,
        compact: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              VirtualActionButton(
                label: 'Start recording',
                icon: Icons.play_arrow_rounded,
                tone: VirtualButtonTone.primary,
                onPressed: _controller.canStart ? _start : null,
                tooltip: _controller.canStart
                    ? 'Start capturing the selected sources'
                    : 'Select a source first, or save the capture that is waiting',
              ),
              if (recording)
                VirtualActionButton(
                  label: 'Pause',
                  icon: Icons.pause_rounded,
                  onPressed: _controller.pause,
                )
              else if (paused)
                VirtualActionButton(
                  label: 'Resume',
                  icon: Icons.play_arrow_rounded,
                  onPressed: _controller.resume,
                ),
              VirtualActionButton(
                label: 'Stop',
                icon: Icons.stop_rounded,
                tone: VirtualButtonTone.danger,
                onPressed: _controller.canStop ? _controller.stop : null,
                tooltip: 'Stop capturing but keep the file to save',
              ),
              VirtualActionButton(
                label: 'Save',
                icon: Icons.save_outlined,
                tone: VirtualButtonTone.primary,
                busy: saving,
                onPressed: _controller.canSave && !saving ? () => _save() : null,
              ),
              VirtualActionButton(
                label: 'End & Save',
                icon: Icons.check_circle_outline,
                tone: VirtualButtonTone.danger,
                busy: saving,
                onPressed: _controller.canSave && !saving ? () => _save(end: true) : null,
                tooltip: 'Stop, upload to Recordings, and release every source',
              ),
              if (_controller.hasPendingCapture)
                VirtualActionButton(
                  label: 'Discard',
                  icon: Icons.delete_outline,
                  tone: VirtualButtonTone.ghost,
                  onPressed: _discard,
                ),
              if (_controller.phase == VirtualRecordingPhase.saved && !_controller.hasLiveSource)
                VirtualActionButton(
                  label: 'New session',
                  icon: Icons.refresh,
                  tone: VirtualButtonTone.ghost,
                  onPressed: _resetSession,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _labelField(),
        ],
      ),
    );
  }

  Widget _labelField() => TextField(
        controller: _label,
        style: const TextStyle(color: VtcPalette.textPrimary, fontSize: 13),
        cursorColor: VtcPalette.focus,
        onSubmitted: (_) => _labelEdited = true,
        decoration: InputDecoration(
          labelText: 'Recording name',
          hintText: _controller.suggestedLabel,
          hintStyle: const TextStyle(color: VtcPalette.textMuted, fontSize: 12),
          labelStyle: const TextStyle(color: VtcPalette.textMuted, fontSize: 12),
          filled: true,
          fillColor: VtcPalette.input,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: VtcPalette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: VtcPalette.focus, width: 1.4),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: VtcPalette.border),
          ),
        ),
      );

  // -- meeting controls -----------------------------------------------------

  Widget _meetingControls() {
    final bool busy = _controller.isBusy;
    return VirtualCard(
      title: 'Meeting controls',
      icon: Icons.dashboard_customize_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _controlChip(
                label: _controller.microphoneRequested ? 'Microphone on' : 'Microphone off',
                icon: _controller.microphoneRequested ? Icons.mic : Icons.mic_off_outlined,
                state: _micState,
                active: _controller.microphoneRequested,
                onTap: busy ? null : _toggleMic,
                tooltip: _controller.microphoneRequested ? 'Turn the microphone off' : 'Use the selected microphone',
              ),
              if (_controller.microphoneRequested)
                _controlChip(
                  label: _controller.microphoneMuted ? 'Unmute' : 'Mute',
                  icon: _controller.microphoneMuted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                  state: _controller.microphoneMuted ? SourceState.noSignal : SourceState.active,
                  active: _controller.microphoneMuted,
                  onTap: busy ? null : () => _controller.setMicrophoneMuted(!_controller.microphoneMuted),
                  tooltip: _controller.microphoneMuted ? 'Unmute the microphone' : 'Mute the microphone',
                ),
              _controlChip(
                label: _controller.cameraRequested ? 'Camera on' : 'Camera off',
                icon: _controller.cameraRequested ? Icons.videocam : Icons.videocam_off_outlined,
                state: _cameraState,
                active: _controller.cameraRequested,
                onTap: busy ? null : _toggleCamera,
                tooltip: _controller.cameraRequested ? 'Turn the camera off' : 'Use the selected camera',
              ),
              _controlChip(
                label: _controller.screenShared ? 'Stop sharing' : 'Share screen',
                icon: _controller.screenShared ? Icons.stop_screen_share_outlined : Icons.screen_share_outlined,
                state: _screenState,
                active: _controller.screenShared,
                onTap: busy ? null : _toggleScreen,
                tooltip: _controller.screenShared ? 'Stop sharing the screen or tab' : 'Share a tab, window or screen',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Text(
                'Record',
                style: TextStyle(color: VtcPalette.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: VtcPalette.input,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: VtcPalette.border),
                  ),
                  child: Row(
                    children: <Widget>[
                      _modeButton('Audio only', VirtualRecordingMode.audio, Icons.headphones_outlined),
                      _modeButton('Audio + video', VirtualRecordingMode.video, Icons.movie_outlined),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _controller.mode == VirtualRecordingMode.video
                ? 'Video mode records the shared screen or camera. If no audio source is on, the file is video only.'
                : 'Audio mode records the microphone and any shared tab audio. No video track is written.',
            style: const TextStyle(color: VtcPalette.textMuted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _modeButton(String label, VirtualRecordingMode mode, IconData icon) {
    final bool selected = _controller.mode == mode;
    final bool locked = _controller.isRecording || _controller.isPaused || _controller.hasPendingCapture;
    return Expanded(
      child: InkWell(
        onTap: locked ? null : () => _controller.setMode(mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? VtcPalette.elevated : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? VtcPalette.borderActive : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 15, color: selected ? VtcPalette.textPrimary : VtcPalette.textMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? VtcPalette.textPrimary : VtcPalette.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlChip({
    required String label,
    required IconData icon,
    required SourceState state,
    required bool active,
    required VoidCallback? onTap,
    String? tooltip,
  }) {
    final bool enabled = onTap != null;
    final Color stateColor = sourceStateColor(state);
    final Widget chip = Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          focusColor: VtcPalette.focus.withValues(alpha: 0.15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              color: active ? VtcPalette.elevated : VtcPalette.input,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? VtcPalette.borderActive : VtcPalette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 16, color: active ? VtcPalette.textPrimary : VtcPalette.textSecondary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? VtcPalette.textPrimary : VtcPalette.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: stateColor, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
  }

  // -- status ---------------------------------------------------------------

  Widget _statusStrip() {
    final String? error = _controller.error;
    final String? notice = _controller.notice;
    if (error != null) {
      return VirtualNotice(message: error, isError: true, onDismiss: _controller.clearNotice);
    }
    if (notice != null) {
      return VirtualNotice(message: notice, onDismiss: _controller.clearNotice);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: VtcPalette.workspace,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: VtcPalette.divider),
      ),
      child: Row(
        children: <Widget>[
          Icon(_phaseIcon, size: 14, color: _phaseColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _phaseExplanation,
              style: const TextStyle(color: VtcPalette.textMuted, fontSize: 11.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  String get _phaseExplanation {
    switch (_controller.phase) {
      case VirtualRecordingPhase.unsupported:
        return 'This browser does not expose media capture. Nothing can be recorded here.';
      case VirtualRecordingPhase.idle:
        return 'Choose a microphone, camera or screen to begin. Nothing is captured until you start.';
      case VirtualRecordingPhase.ready:
        return _controller.hasPendingCapture
            ? 'Capture stopped. Save it to Recordings or discard it.'
            : 'Sources are ready. Start recording when you are.';
      case VirtualRecordingPhase.connecting:
        return 'Asking the browser for the selected source…';
      case VirtualRecordingPhase.recording:
        return 'Recording the selected sources. The timer matches the file being written.';
      case VirtualRecordingPhase.paused:
        return 'Paused. The timer is stopped and the file is not growing.';
      case VirtualRecordingPhase.finalizing:
        return 'Stopping the recorder and verifying that the file can be played back…';
      case VirtualRecordingPhase.saving:
        return 'Uploading the verified capture to the shared Recordings library…';
      case VirtualRecordingPhase.saved:
        return 'Saved. The recording is in the library and can be transcribed there.';
      case VirtualRecordingPhase.failed:
        return 'The last action failed. The message above explains what the browser or server reported.';
    }
  }

  // -- right panel ----------------------------------------------------------

  Widget _rightPanel() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          VirtualCard(
            padding: const EdgeInsets.all(10),
            child: _panelTabs(),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: switch (_panelTab) {
              1 => _audioTab(),
              2 => _recordingTab(),
              _ => _sourcesTab(),
            },
          ),
          const SizedBox(height: 10),
          _panelStatusCard(),
        ],
      );

  Widget _panelTabs() {
    final List<String> labels = <String>['Sources', 'Audio', 'Recording'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: VtcPalette.input,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: VtcPalette.border),
      ),
      child: Row(
        children: List<Widget>.generate(labels.length, (int index) {
          final bool selected = _panelTab == index;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _panelTab = index),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? VtcPalette.elevated : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? VtcPalette.borderActive : Colors.transparent),
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? VtcPalette.textPrimary : VtcPalette.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _sourcesTab() => VirtualCard(
        key: const ValueKey<String>('sources-tab'),
        title: 'Sources',
        icon: Icons.input,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _sourceSection(
              title: 'Microphone',
              icon: Icons.mic_none_outlined,
              state: _micState,
              message: _controller.messageOf(CaptureSourceKind.microphone),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _deviceDropdown(
                    devices: _controller.microphones,
                    value: _controller.microphoneId,
                    fallback: 'Default microphone',
                    onChanged: _controller.selectMicrophone,
                  ),
                  const SizedBox(height: 8),
                  VirtualActionButton(
                    label: _controller.microphoneRequested ? 'Turn off microphone' : 'Use microphone',
                    icon: _controller.microphoneRequested ? Icons.mic_off_outlined : Icons.mic_none_outlined,
                    onPressed: _controller.isBusy ? null : _toggleMic,
                    expand: true,
                  ),
                ],
              ),
            ),
            const Divider(height: 22, color: VtcPalette.divider),
            _sourceSection(
              title: 'Camera',
              icon: Icons.videocam_outlined,
              state: _cameraState,
              message: _controller.messageOf(CaptureSourceKind.camera),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _deviceDropdown(
                    devices: _controller.cameras,
                    value: _controller.cameraId,
                    fallback: 'Default camera',
                    onChanged: _controller.selectCamera,
                  ),
                  const SizedBox(height: 8),
                  VirtualActionButton(
                    label: _controller.cameraRequested ? 'Turn off camera' : 'Use camera',
                    icon: _controller.cameraRequested ? Icons.videocam_off_outlined : Icons.videocam_outlined,
                    onPressed: _controller.isBusy ? null : _toggleCamera,
                    expand: true,
                  ),
                ],
              ),
            ),
            const Divider(height: 22, color: VtcPalette.divider),
            _sourceSection(
              title: 'Screen & system audio',
              icon: Icons.desktop_windows_outlined,
              state: _screenState,
              message: _controller.messageOf(CaptureSourceKind.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  VirtualActionButton(
                    label: _controller.screenShared ? 'Stop sharing' : 'Share a tab or screen',
                    icon: _controller.screenShared ? Icons.stop_screen_share_outlined : Icons.screen_share_outlined,
                    tone: _controller.screenShared ? VirtualButtonTone.danger : VirtualButtonTone.primary,
                    onPressed: _controller.isBusy ? null : _toggleScreen,
                    expand: true,
                  ),
                  if (_controller.screenInfo != null) ...<Widget>[
                    const SizedBox(height: 10),
                    VirtualInfoRow(
                        label: 'Shared surface', value: _controller.screenInfo!.label, icon: Icons.crop_free),
                    if (_controller.screenInfo!.width > 0)
                      VirtualInfoRow(
                        label: 'Resolution',
                        value: '${_controller.screenInfo!.width} × ${_controller.screenInfo!.height}',
                        icon: Icons.aspect_ratio,
                      ),
                    VirtualInfoRow(
                      label: 'System / tab audio',
                      value: sourceStateLabel(_systemState),
                      valueColor: sourceStateColor(_systemState),
                      icon: Icons.volume_up_outlined,
                    ),
                    if (_controller.messageOf(CaptureSourceKind.systemAudio) != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _controller.messageOf(CaptureSourceKind.systemAudio)!,
                          style: const TextStyle(color: VtcPalette.warning, fontSize: 11, height: 1.4),
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'When the browser asks what to share, tick “Share tab audio” to capture meeting sound. Screen audio is only available for tabs and some windows.',
                    style: TextStyle(color: VtcPalette.textMuted, fontSize: 10.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const Divider(height: 22, color: VtcPalette.divider),
            const Text(
              'Selected sources',
              style: TextStyle(color: VtcPalette.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedSourceSummary,
              style: const TextStyle(color: VtcPalette.textSecondary, fontSize: 11.5, height: 1.4),
            ),
          ],
        ),
      );

  Widget _sourceSection({
    required String title,
    required IconData icon,
    required SourceState state,
    required Widget child,
    String? message,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: VtcPalette.textSecondary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: VtcPalette.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              VirtualPill(
                label: sourceStateLabel(state),
                color: sourceStateColor(state),
                icon: sourceStateIcon(state),
                compact: true,
              ),
            ],
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(message, style: const TextStyle(color: VtcPalette.textMuted, fontSize: 10.5, height: 1.4)),
          ],
          const SizedBox(height: 10),
          child,
        ],
      );

  Widget _deviceDropdown({
    required List<CaptureDevice> devices,
    required String? value,
    required String fallback,
    required ValueChanged<String?> onChanged,
  }) {
    final bool hasValue = value != null && devices.any((CaptureDevice device) => device.id == value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: VtcPalette.input,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: VtcPalette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: hasValue ? value : null,
          isExpanded: true,
          dropdownColor: VtcPalette.elevated,
          iconEnabledColor: VtcPalette.textMuted,
          hint: Text(fallback, style: const TextStyle(color: VtcPalette.textMuted, fontSize: 12)),
          style: const TextStyle(color: VtcPalette.textPrimary, fontSize: 12),
          items: devices
              .map(
                (CaptureDevice device) => DropdownMenuItem<String>(
                  value: device.id,
                  child: Text(device.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: devices.isEmpty ? null : onChanged,
        ),
      ),
    );
  }

  Widget _audioTab() => VirtualCard(
        key: const ValueKey<String>('audio-tab'),
        title: 'Audio levels',
        icon: Icons.graphic_eq,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _meterBlock(
              title: 'Microphone',
              icon: Icons.mic_none_outlined,
              level: _controller.microphoneLevel,
              colors: const <Color>[VtcPalette.successBright, VtcPalette.warning],
              active: _controller.microphoneRequested && !_controller.microphoneMuted,
              state: _micState,
              note: _controller.microphoneRequested
                  ? (_controller.microphoneMuted
                      ? 'Muted. The meter is inactive while muted.'
                      : 'Live signal from the selected microphone.')
                  : 'Turn the microphone on to see its real level.',
              trailing: _controller.microphoneRequested
                  ? Switch(
                      value: !_controller.microphoneMuted,
                      onChanged: (bool live) => _controller.setMicrophoneMuted(!live),
                      activeThumbColor: VtcPalette.successBright,
                      inactiveThumbColor: VtcPalette.disabled,
                      inactiveTrackColor: VtcPalette.input,
                    )
                  : null,
            ),
            const Divider(height: 24, color: VtcPalette.divider),
            _meterBlock(
              title: 'System / tab audio',
              icon: Icons.volume_up_outlined,
              level: _controller.systemLevel,
              colors: const <Color>[VtcPalette.cyan, VtcPalette.successBright],
              active: _controller.screenShared && _controller.engine.screenHasAudio,
              state: _systemState,
              note: _controller.screenShared
                  ? (_controller.engine.screenHasAudio
                      ? 'Live signal from the shared tab or screen.'
                      : 'This share exposed no audio track. Re-share and tick “Share tab audio”.')
                  : 'Share a tab with audio to see the system level.',
            ),
            const Divider(height: 24, color: VtcPalette.divider),
            const Text(
              'Meters read the signal the browser is actually receiving. Unlit bars are inactive; the colours run green→yellow for the microphone and cyan→green for system audio.',
              style: TextStyle(color: VtcPalette.textMuted, fontSize: 10.5, height: 1.45),
            ),
          ],
        ),
      );

  Widget _meterBlock({
    required String title,
    required IconData icon,
    required ValueListenable<double> level,
    required List<Color> colors,
    required bool active,
    required SourceState state,
    required String note,
    Widget? trailing,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: VtcPalette.textSecondary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: VtcPalette.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 8),
          VirtualAudioMeter(level: level, colors: colors, active: active, height: 14),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              VirtualPill(
                label: sourceStateLabel(state),
                color: sourceStateColor(state),
                icon: sourceStateIcon(state),
                compact: true,
              ),
              const Spacer(),
              ValueListenableBuilder<double>(
                valueListenable: level,
                builder: (BuildContext context, double value, Widget? child) => Text(
                  active ? '${(value.clamp(0.0, 1.0) * 100).round()}%' : '—',
                  style: const TextStyle(color: VtcPalette.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(note, style: const TextStyle(color: VtcPalette.textMuted, fontSize: 10.5, height: 1.4)),
        ],
      );

  Widget _recordingTab() {
    final bool hasCapture = _controller.hasPendingCapture;
    final bool saving = _controller.phase == VirtualRecordingPhase.saving;
    return VirtualCard(
      key: const ValueKey<String>('recording-tab'),
      title: 'Recording information',
      icon: Icons.assignment_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          VirtualInfoRow(label: 'Status', value: _phaseLabel, valueColor: _phaseColor, icon: _phaseIcon),
          VirtualInfoRow(
            label: hasCapture ? 'Captured duration' : 'Duration',
            value: formatDuration(hasCapture ? _controller.pendingDuration : _controller.elapsed),
            icon: Icons.timer_outlined,
          ),
          VirtualInfoRow(
            label: _controller.isEstimate ? 'Estimated size' : 'Recorded size',
            value: formatBytes(_controller.estimatedBytes),
            icon: Icons.data_usage_outlined,
          ),
          VirtualInfoRow(label: 'Actual format', value: _controller.formatLabel, icon: Icons.movie_filter_outlined),
          VirtualInfoRow(
              label: 'Mode',
              value: _controller.mode == VirtualRecordingMode.video ? 'Audio + video' : 'Audio only',
              icon: Icons.category_outlined),
          VirtualInfoRow(label: 'Sources', value: _selectedSourceSummary, icon: Icons.sensors),
          VirtualInfoRow(
            label: 'Microphone',
            value: sourceStateLabel(_micState),
            valueColor: sourceStateColor(_micState),
            icon: Icons.mic_none_outlined,
          ),
          VirtualInfoRow(
            label: 'System / tab audio',
            value: sourceStateLabel(_systemState),
            valueColor: sourceStateColor(_systemState),
            icon: Icons.volume_up_outlined,
          ),
          VirtualInfoRow(
            label: 'Screen',
            value: sourceStateLabel(_screenState),
            valueColor: sourceStateColor(_screenState),
            icon: Icons.desktop_windows_outlined,
          ),
          VirtualInfoRow(
            label: 'Camera',
            value: sourceStateLabel(_cameraState),
            valueColor: sourceStateColor(_cameraState),
            icon: Icons.videocam_outlined,
          ),
          if (_controller.storageWarning != null) ...<Widget>[
            const SizedBox(height: 8),
            VirtualNotice(message: _controller.storageWarning!),
          ],
          const Divider(height: 22, color: VtcPalette.divider),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              VirtualActionButton(
                label: 'Save',
                icon: Icons.save_outlined,
                tone: VirtualButtonTone.primary,
                busy: saving,
                onPressed: _controller.canSave && !saving ? () => _save() : null,
              ),
              VirtualActionButton(
                label: 'End & Save',
                icon: Icons.check_circle_outline,
                tone: VirtualButtonTone.danger,
                busy: saving,
                onPressed: _controller.canSave && !saving ? () => _save(end: true) : null,
              ),
              if (hasCapture)
                VirtualActionButton(
                  label: 'Discard',
                  icon: Icons.delete_outline,
                  tone: VirtualButtonTone.ghost,
                  onPressed: saving ? null : _discard,
                ),
            ],
          ),
          if (_controller.phase == VirtualRecordingPhase.saved && _controller.savedRecording != null) ...<Widget>[
            const SizedBox(height: 10),
            VirtualNotice(
              message: 'Saved “${_controller.savedRecording!['label'] ?? 'Virtual recording'}” to Recordings. '
                  'Transcription uses the configured speech service on that page.',
            ),
            const SizedBox(height: 8),
            if (widget.onOpenLibrary != null)
              VirtualActionButton(
                label: 'Open Recordings',
                icon: Icons.library_music_outlined,
                onPressed: widget.onOpenLibrary,
                expand: true,
              ),
          ],
        ],
      ),
    );
  }

  Widget _panelStatusCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VtcPalette.workspace,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VtcPalette.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(_phaseIcon, size: 16, color: _phaseColor),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _phaseLabel,
                    style: TextStyle(color: _phaseColor, fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _phaseExplanation,
                    style: const TextStyle(color: VtcPalette.textMuted, fontSize: 10.5, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
