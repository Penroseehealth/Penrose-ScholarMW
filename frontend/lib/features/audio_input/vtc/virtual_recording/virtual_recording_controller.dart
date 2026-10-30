import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/networking/api_client.dart';
import 'capture_engine.dart';

/// What the user is recording. Video mode needs a screen or camera; audio mode
/// needs a microphone or the audio track of a shared tab/screen.
enum VirtualRecordingMode { audio, video }

enum VirtualRecordingPhase {
  unsupported,
  idle,
  ready,
  connecting,
  recording,
  paused,
  finalizing,
  saving,
  saved,
  failed,
}

/// State and real side effects for the Virtual Recording page.
///
/// The controller never invents a source, a level, a duration or a saved file:
/// every value comes from [VirtualCaptureEngine] or from the backend upload.
class VirtualRecordingController extends ChangeNotifier {
  VirtualRecordingController({required this.apiClient, VirtualCaptureEngine? engine})
      : _engine = engine ?? VirtualCapture.create();

  final ApiClient apiClient;
  final VirtualCaptureEngine _engine;

  final ValueNotifier<double> microphoneLevel = ValueNotifier<double>(0);
  final ValueNotifier<double> systemLevel = ValueNotifier<double>(0);

  VirtualRecordingPhase _phase = VirtualRecordingPhase.idle;
  VirtualRecordingPhase get phase => _phase;

  VirtualRecordingMode _mode = VirtualRecordingMode.audio;
  VirtualRecordingMode get mode => _mode;

  String? _error;
  String? get error => _error;

  String? _notice;
  String? get notice => _notice;

  List<CaptureDevice> _microphones = const <CaptureDevice>[];
  List<CaptureDevice> get microphones => _microphones;

  List<CaptureDevice> _cameras = const <CaptureDevice>[];
  List<CaptureDevice> get cameras => _cameras;

  String? _microphoneId;
  String? get microphoneId => _microphoneId;

  String? _cameraId;
  String? get cameraId => _cameraId;

  bool _microphoneRequested = false;
  bool get microphoneRequested => _microphoneRequested;

  bool _cameraRequested = false;
  bool get cameraRequested => _cameraRequested;

  bool _microphoneMuted = false;
  bool get microphoneMuted => _microphoneMuted;

  bool _screenShared = false;
  bool get screenShared => _screenShared;

  ScreenShareInfo? _screenInfo;
  ScreenShareInfo? get screenInfo => _screenInfo;

  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  Duration _pendingDuration = Duration.zero;
  Duration get pendingDuration => _pendingDuration;

  int _bytes = 0;
  int get bytes => _bytes;

  RecordedCapture? _pending;
  bool get hasPendingCapture => _pending != null;

  Map<String, dynamic>? _saved;
  Map<String, dynamic>? get savedRecording => _saved;

  DateTime? _startedAt;
  Duration _accumulated = Duration.zero;
  DateTime? _segmentStartedAt;

  Timer? _clock;
  Timer? _meter;
  bool _initialised = false;
  bool _disposed = false;

  DateTime? _microphoneSignalAt;
  DateTime? _systemSignalAt;

  final Map<CaptureSourceKind, SourceState> _states = <CaptureSourceKind, SourceState>{
    CaptureSourceKind.microphone: SourceState.notSelected,
    CaptureSourceKind.systemAudio: SourceState.notSelected,
    CaptureSourceKind.screen: SourceState.notSelected,
    CaptureSourceKind.camera: SourceState.notSelected,
  };
  final Map<CaptureSourceKind, String?> _messages = <CaptureSourceKind, String?>{
    CaptureSourceKind.microphone: null,
    CaptureSourceKind.systemAudio: null,
    CaptureSourceKind.screen: null,
    CaptureSourceKind.camera: null,
  };

  VirtualCaptureEngine get engine => _engine;

  bool get isSupported => _engine.supported;

  bool get isRecording => _phase == VirtualRecordingPhase.recording;

  bool get isPaused => _phase == VirtualRecordingPhase.paused;

  bool get isBusy =>
      _phase == VirtualRecordingPhase.connecting ||
      _phase == VirtualRecordingPhase.finalizing ||
      _phase == VirtualRecordingPhase.saving;

  bool get hasLiveSource => _microphoneRequested || _cameraRequested || _screenShared;

  bool get hasAudioSource => _microphoneRequested || _engine.screenHasAudio;

  bool get hasVideoSource => _screenShared || _cameraRequested;

  bool get canStart {
    if (!isSupported || isBusy || isRecording || isPaused) return false;
    if (hasPendingCapture) return false;
    return _mode == VirtualRecordingMode.video ? hasVideoSource : hasAudioSource;
  }

  bool get canPause => isRecording;

  bool get canResume => isPaused;

  bool get canStop => isRecording || isPaused;

  bool get canSave => hasPendingCapture || isRecording || isPaused;

  SourceState stateOf(CaptureSourceKind kind) => _states[kind] ?? SourceState.notSelected;

  String? messageOf(CaptureSourceKind kind) => _messages[kind];

  /// Label suggested for a new capture, based on when it actually started.
  String get suggestedLabel {
    final DateTime when = _startedAt ?? DateTime.now();
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final String hour = when.hour.toString().padLeft(2, '0');
    final String minute = when.minute.toString().padLeft(2, '0');
    return 'Virtual recording ${when.day} ${months[when.month - 1]} $hour:$minute';
  }

  /// Format that will actually be produced, taken from runtime support checks.
  String get formatLabel {
    final MediaFormat? active = _engine.activeFormat;
    if (active != null) return '${active.label} (.${active.extension})';
    final CaptureCapabilities caps = _engine.capabilities;
    final List<String> formats = _mode == VirtualRecordingMode.video ? caps.videoFormats : caps.audioFormats;
    if (formats.isEmpty) return isSupported ? 'No supported container' : 'Unsupported';
    final String base = formats.first.split(';').first;
    switch (base) {
      case 'video/webm':
        return 'WebM video';
      case 'video/mp4':
        return 'MP4 video';
      case 'video/quicktime':
        return 'QuickTime video';
      case 'audio/webm':
        return 'WebM audio (Opus)';
      case 'audio/ogg':
        return 'Ogg audio (Opus)';
      case 'audio/mp4':
        return 'MP4 audio (AAC)';
      case 'audio/mpeg':
        return 'MP3 audio';
    }
    return base;
  }

  /// Size hint for the right panel. Once the browser has written data this is
  /// the real byte count; before that it is a clearly-labelled estimate.
  int get estimatedBytes {
    if (_bytes > 0) return _bytes;
    if (_elapsed == Duration.zero) return 0;
    final double seconds = _elapsed.inMilliseconds / 1000.0;
    final int perSecond = _mode == VirtualRecordingMode.video ? 330 * 1024 : 16 * 1024;
    return (seconds * perSecond).round();
  }

  bool get isEstimate => _bytes == 0 && _elapsed > Duration.zero;

  /// Storage warning for the 2 GB backend limit.
  String? get storageWarning {
    final int estimate = estimatedBytes;
    if (estimate >= 1900 * 1024 * 1024) {
      return 'Close to the 2 GB upload limit. Save now or record a shorter session.';
    }
    if (estimate >= 1200 * 1024 * 1024) {
      return 'Large capture. Keeping this tab open until it is saved avoids losing it.';
    }
    return null;
  }

  Future<void> initialize() async {
    if (_initialised) return;
    _initialised = true;
    if (!_engine.supported) {
      _phase = VirtualRecordingPhase.unsupported;
      _notify();
      return;
    }
    _phase = VirtualRecordingPhase.idle;
    _engine.setScreenShareEndedCallback(_handleScreenEnded);
    _startMeters();
    await refreshDevices();
    _notify();
  }

  Future<void> refreshDevices() async {
    if (!_engine.supported) return;
    _microphones = await _engine.microphones();
    _cameras = await _engine.cameras();
    _notify();
  }

  void setMode(VirtualRecordingMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    _notify();
  }

  void selectMicrophone(String? id) {
    _microphoneId = id;
    _notify();
  }

  void selectCamera(String? id) {
    _cameraId = id;
    _notify();
  }

  void setMicrophoneMuted(bool muted) {
    _microphoneMuted = muted;
    _engine.setMicrophoneMuted(muted);
    _notify();
  }

  Future<void> toggleMicrophone() async {
    if (_microphoneRequested) {
      await _stopMicrophone();
      return;
    }
    _setState(CaptureSourceKind.microphone, SourceState.connecting);
    _notify();
    try {
      await _engine.startMicrophone(deviceId: _microphoneId);
      _microphoneRequested = true;
      _microphoneMuted = false;
      _setState(CaptureSourceKind.microphone, SourceState.active);
      await refreshDevices();
      _syncPhase();
    } on CaptureFailure catch (failure) {
      _applyFailure(CaptureSourceKind.microphone, failure);
    } catch (error) {
      _setState(CaptureSourceKind.microphone, SourceState.permissionDenied, 'Microphone unavailable: $error');
    }
    _notify();
  }

  Future<void> _stopMicrophone() async {
    await _engine.stopMicrophone();
    _microphoneRequested = false;
    _microphoneMuted = false;
    _setState(CaptureSourceKind.microphone, SourceState.notSelected);
    _syncPhase();
    _notify();
  }

  Future<void> toggleCamera() async {
    if (_cameraRequested) {
      await _engine.stopCamera();
      _cameraRequested = false;
      _setState(CaptureSourceKind.camera, SourceState.notSelected);
      _syncPhase();
      _notify();
      return;
    }
    _setState(CaptureSourceKind.camera, SourceState.connecting);
    _notify();
    try {
      await _engine.startCamera(deviceId: _cameraId);
      _cameraRequested = true;
      _setState(CaptureSourceKind.camera, SourceState.active);
      await refreshDevices();
      _syncPhase();
    } on CaptureFailure catch (failure) {
      _applyFailure(CaptureSourceKind.camera, failure);
    } catch (error) {
      _setState(CaptureSourceKind.camera, SourceState.permissionDenied, 'Camera unavailable: $error');
    }
    _notify();
  }

  Future<void> toggleScreenShare() async {
    if (_screenShared) {
      await _stopScreenShare();
      return;
    }
    _setState(CaptureSourceKind.screen, SourceState.connecting);
    _setState(CaptureSourceKind.systemAudio, SourceState.connecting);
    _notify();
    try {
      final ScreenShareInfo info = await _engine.startScreenShare();
      _screenShared = true;
      _screenInfo = info;
      _setState(CaptureSourceKind.screen, SourceState.active);
      if (info.hasAudio) {
        _setState(CaptureSourceKind.systemAudio, SourceState.active);
      } else {
        _setState(
          CaptureSourceKind.systemAudio,
          SourceState.noSignal,
          'This surface was shared without audio. Share a tab or screen with "share audio" enabled to record it.',
        );
      }
      if (info.hasAudio && _mode == VirtualRecordingMode.audio) {
        // The user may record the tab's audio only; do not silently switch the
        // mode behind their back. The mode stays whatever they chose.
        _notice = 'System audio is available from this share.';
      }
      _syncPhase();
    } on CaptureFailure catch (failure) {
      _applyFailure(CaptureSourceKind.screen, failure);
      _setState(CaptureSourceKind.systemAudio, SourceState.notSelected);
    } catch (error) {
      _setState(CaptureSourceKind.screen, SourceState.permissionDenied, 'Screen share unavailable: $error');
      _setState(CaptureSourceKind.systemAudio, SourceState.notSelected);
    }
    _notify();
  }

  Future<void> _stopScreenShare() async {
    await _engine.stopScreenShare();
    _screenShared = false;
    _screenInfo = null;
    _setState(CaptureSourceKind.screen, SourceState.notSelected);
    _setState(CaptureSourceKind.systemAudio, SourceState.notSelected);
    _syncPhase();
    _notify();
  }

  void _handleScreenEnded() {
    if (_disposed) return;
    _screenShared = false;
    _screenInfo = null;
    _setState(CaptureSourceKind.screen, SourceState.notSelected);
    _setState(
      CaptureSourceKind.systemAudio,
      SourceState.notSelected,
      'Screen sharing stopped in the browser.',
    );
    if (isRecording || isPaused) {
      _error = 'The shared screen stopped. The recording kept what was captured so far; use Stop to save it.';
    } else {
      _notice = 'Screen sharing stopped.';
    }
    _syncPhase();
    _notify();
  }

  void _applyFailure(CaptureSourceKind kind, CaptureFailure failure) {
    final SourceState state = failure.permissionDenied
        ? SourceState.permissionDenied
        : failure.deviceLost
            ? SourceState.deviceDisconnected
            : failure.unsupported
                ? SourceState.unsupported
                : SourceState.notSelected;
    _setState(kind, state, failure.message);
    _error = failure.message;
  }

  Future<void> start() async {
    if (!canStart) {
      if (hasPendingCapture) {
        _error = 'Save or discard the captured recording before starting another.';
      } else if (_mode == VirtualRecordingMode.video && !hasVideoSource) {
        _error = 'Turn on the screen or camera, or switch to audio-only.';
      } else if (_mode == VirtualRecordingMode.audio && !hasAudioSource) {
        _error = 'Turn on the microphone or share a tab with audio.';
      }
      _notify();
      return;
    }
    _error = null;
    _notice = null;
    _phase = VirtualRecordingPhase.connecting;
    _notify();
    try {
      await _engine.startRecording(includeVideo: _mode == VirtualRecordingMode.video);
      _bytes = 0;
      _pending = null;
      _pendingDuration = Duration.zero;
      _elapsed = Duration.zero;
      _accumulated = Duration.zero;
      _segmentStartedAt = DateTime.now();
      _startedAt = DateTime.now();
      _phase = VirtualRecordingPhase.recording;
      _startClock();
    } on CaptureFailure catch (failure) {
      _phase = VirtualRecordingPhase.failed;
      _error = failure.message;
    } catch (error) {
      _phase = VirtualRecordingPhase.failed;
      _error = 'Recording could not start: $error';
    }
    _notify();
  }

  void pause() {
    if (!canPause) return;
    _engine.pauseRecording();
    _accumulateSegment();
    _phase = VirtualRecordingPhase.paused;
    _notify();
  }

  void resume() {
    if (!canResume) return;
    _engine.resumeRecording();
    _segmentStartedAt = DateTime.now();
    _phase = VirtualRecordingPhase.recording;
    _notify();
  }

  Future<void> stop() async {
    if (!canStop) return;
    _phase = VirtualRecordingPhase.finalizing;
    _notify();
    try {
      await _finalizeCapture();
      _phase = _pending == null ? _restingPhase : VirtualRecordingPhase.ready;
      _notice = _pending == null ? null : 'Recording stopped. Save it to add it to the library, or discard it.';
    } on CaptureFailure catch (failure) {
      _phase = VirtualRecordingPhase.failed;
      _error = failure.message;
      _pending = null;
    } catch (error) {
      _phase = VirtualRecordingPhase.failed;
      _error = 'Stopping the recording failed: $error';
      _pending = null;
    }
    _notify();
  }

  Future<void> _finalizeCapture() async {
    _accumulateSegment();
    final Duration captured = _elapsed;
    final RecordedCapture result = await _engine.stopRecording();
    _bytes = result.bytes.length;
    _pendingDuration = captured;
    _pending = RecordedCapture(
      bytes: result.bytes,
      mimeType: result.mimeType,
      hasVideo: result.hasVideo,
      duration: captured,
      audioBytes: result.audioBytes,
      audioMimeType: result.audioMimeType,
    );
    _stopClock();
  }

  void _accumulateSegment() {
    final DateTime? segmentStart = _segmentStartedAt;
    if (segmentStart != null) {
      _accumulated += DateTime.now().difference(segmentStart);
      _segmentStartedAt = null;
    }
    _elapsed = _accumulated;
  }

  /// Saves the pending capture (or stops and saves a running one) through the
  /// existing system-audio API so it joins the shared recordings library.
  Future<bool> save({String? label, bool endSession = false}) async {
    if (_phase == VirtualRecordingPhase.saving) return false;
    if (isRecording || isPaused) {
      await stop();
      if (_pending == null) return false;
    }
    final RecordedCapture? capture = _pending;
    if (capture == null) {
      _error = 'There is no finished recording to save yet.';
      _notify();
      return false;
    }
    _phase = VirtualRecordingPhase.saving;
    _error = null;
    _notice = null;
    _notify();
    try {
      final String extension = _extensionFor(capture.mimeType);
      final List<String> sources = <String>[
        if (_microphoneRequested) 'microphone',
        if (_screenShared && _engine.screenHasAudio) 'system audio',
        if (capture.hasVideo)
          if (_screenShared) 'screen' else 'camera',
      ];
      final Map<String, dynamic> result = await apiClient.postMultipart(
        '/system-audio/virtual-recordings',
        fields: <String, String>{
          'label': (label ?? '').trim().isEmpty ? suggestedLabel : label!.trim(),
          'duration_seconds': (capture.duration.inMilliseconds / 1000).toStringAsFixed(3),
          'mime_type': capture.mimeType,
          'media_type': capture.hasVideo ? 'video' : 'audio',
          'sources': sources.join(','),
          'started_at': (_startedAt ?? DateTime.now()).toUtc().toIso8601String(),
        },
        files: <MultipartFilePart>[
          MultipartFilePart(
            name: 'file',
            filename: 'recording.$extension',
            bytes: capture.bytes,
            contentType: capture.mimeType,
          ),
          if (capture.audioBytes != null && capture.audioMimeType != null)
            MultipartFilePart(
              name: 'audio_file',
              filename: 'speech.${_extensionFor(capture.audioMimeType!)}',
              bytes: capture.audioBytes!,
              contentType: capture.audioMimeType,
            ),
        ],
      );
      final String id = (result['id'] ?? '').toString();
      if (id.isEmpty) {
        throw const ApiException(
          'The backend saved the file but did not return a recording id, so it cannot be added to the library.',
          code: 'invalid_response',
        );
      }
      _saved = result;
      _pending = null;
      _phase = VirtualRecordingPhase.saved;
      _notice = 'Saved to Recordings as "${result['label'] ?? suggestedLabel}".';
      if (endSession) {
        await _stopAllSources();
      }
      _notify();
      return true;
    } on AppException catch (exception) {
      _phase = VirtualRecordingPhase.ready;
      _error = exception.message;
      _notify();
      return false;
    } catch (error) {
      _phase = VirtualRecordingPhase.ready;
      _error = 'Saving failed: $error';
      _notify();
      return false;
    }
  }

  /// End and save: finishes the current capture, uploads it, then releases the
  /// microphone, camera and screen share.
  Future<bool> endAndSave({String? label}) => save(label: label, endSession: true);

  Future<void> discard() async {
    _phase = VirtualRecordingPhase.finalizing;
    _notify();
    try {
      await _engine.discardRecording();
      _pending = null;
      _pendingDuration = Duration.zero;
      _bytes = 0;
      _elapsed = Duration.zero;
      _accumulated = Duration.zero;
      _segmentStartedAt = null;
      _stopClock();
      _notice = 'Capture discarded.';
      _phase = _restingPhase;
    } catch (error) {
      _phase = VirtualRecordingPhase.failed;
      _error = 'Discarding the capture failed: $error';
    }
    _notify();
  }

  /// Releases every source and returns to an idle workspace.
  Future<void> resetSession() async {
    await _stopAllSources();
    _pending = null;
    _pendingDuration = Duration.zero;
    _bytes = 0;
    _elapsed = Duration.zero;
    _accumulated = Duration.zero;
    _segmentStartedAt = null;
    _saved = null;
    _error = null;
    _notice = null;
    _stopClock();
    _phase = isSupported ? VirtualRecordingPhase.idle : VirtualRecordingPhase.unsupported;
    _notify();
  }

  Future<void> _stopAllSources() async {
    await _engine.stopMicrophone();
    await _engine.stopCamera();
    await _engine.stopScreenShare();
    _microphoneRequested = false;
    _microphoneMuted = false;
    _cameraRequested = false;
    _screenShared = false;
    _screenInfo = null;
    for (final CaptureSourceKind kind in CaptureSourceKind.values) {
      _setState(kind, SourceState.notSelected);
    }
  }

  VirtualRecordingPhase get _restingPhase {
    if (!isSupported) return VirtualRecordingPhase.unsupported;
    return hasLiveSource ? VirtualRecordingPhase.ready : VirtualRecordingPhase.idle;
  }

  void _syncPhase() {
    if (_phase == VirtualRecordingPhase.unsupported ||
        _phase == VirtualRecordingPhase.recording ||
        _phase == VirtualRecordingPhase.paused ||
        _phase == VirtualRecordingPhase.finalizing ||
        _phase == VirtualRecordingPhase.saving ||
        _phase == VirtualRecordingPhase.saved ||
        _phase == VirtualRecordingPhase.failed) {
      return;
    }
    _phase = _restingPhase;
  }

  void _setState(CaptureSourceKind kind, SourceState state, [String? message]) {
    _states[kind] = state;
    _messages[kind] = message;
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  // -- timers ---------------------------------------------------------------

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!isRecording) return;
      final DateTime? segmentStart = _segmentStartedAt;
      if (segmentStart == null) return;
      final Duration next = _accumulated + DateTime.now().difference(segmentStart);
      if (next.inSeconds != _elapsed.inSeconds) {
        _elapsed = next;
        _notify();
      }
    });
  }

  void _stopClock() {
    _clock?.cancel();
    _clock = null;
  }

  void _startMeters() {
    _meter?.cancel();
    _meter = Timer.periodic(const Duration(milliseconds: 90), (_) {
      final double mic = _engine.readMicrophoneLevel();
      final double system = _engine.readSystemLevel();
      microphoneLevel.value = mic;
      systemLevel.value = system;
      final DateTime now = DateTime.now();
      if (mic > 0.02) _microphoneSignalAt = now;
      if (system > 0.02) _systemSignalAt = now;

      if (_microphoneRequested) {
        if (!_engine.microphoneLive) {
          _microphoneRequested = false;
          _microphoneMuted = false;
          _setState(
            CaptureSourceKind.microphone,
            SourceState.deviceDisconnected,
            'The microphone disconnected or was taken by another app.',
          );
          _syncPhase();
          _notify();
        } else {
          final bool heard =
              _microphoneSignalAt != null && now.difference(_microphoneSignalAt!) < const Duration(seconds: 3);
          final SourceState next = heard ? SourceState.audioDetected : SourceState.active;
          if (_states[CaptureSourceKind.microphone] != next) {
            _setState(CaptureSourceKind.microphone, next);
          }
        }
      }

      if (_screenShared && !_engine.screenActive) {
        _handleScreenEnded();
      } else if (_screenShared && _engine.screenHasAudio) {
        final bool heard = _systemSignalAt != null && now.difference(_systemSignalAt!) < const Duration(seconds: 3);
        final SourceState next = heard ? SourceState.audioDetected : SourceState.active;
        if (_states[CaptureSourceKind.systemAudio] != next) {
          _setState(CaptureSourceKind.systemAudio, next);
        }
      }

      if (_cameraRequested && !_engine.cameraLive) {
        _cameraRequested = false;
        _setState(
          CaptureSourceKind.camera,
          SourceState.deviceDisconnected,
          'The camera disconnected or was taken by another app.',
        );
        _syncPhase();
        _notify();
      }

      if (_engine.bytesRecorded > _bytes) {
        _bytes = _engine.bytesRecorded;
        _notify();
      }
    });
  }

  String _extensionFor(String mime) {
    final String base = mime.split(';').first.trim().toLowerCase();
    switch (base) {
      case 'video/webm':
      case 'audio/webm':
        return 'webm';
      case 'audio/ogg':
        return 'ogg';
      case 'video/ogg':
        return 'ogv';
      case 'audio/mp4':
        return 'm4a';
      case 'video/mp4':
        return 'mp4';
      case 'audio/mpeg':
        return 'mp3';
      case 'audio/wav':
        return 'wav';
      case 'video/quicktime':
        return 'mov';
    }
    return 'webm';
  }

  void clearNotice() {
    if (_notice == null && _error == null) return;
    _notice = null;
    _error = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopClock();
    _meter?.cancel();
    _meter = null;
    microphoneLevel.dispose();
    systemLevel.dispose();
    _engine.dispose();
    super.dispose();
  }
}
