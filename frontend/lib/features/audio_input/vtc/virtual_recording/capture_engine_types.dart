import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Which real capture source a control refers to.
enum CaptureSourceKind { microphone, systemAudio, screen, camera }

/// Honest per-source state. "audioDetected" is only ever set from a measured
/// signal, never because a checkbox is ticked.
enum SourceState {
  notSelected,
  permissionRequired,
  connecting,
  active,
  audioDetected,
  noSignal,
  permissionDenied,
  deviceDisconnected,
  unsupported,
}

/// One enumerable microphone or camera.
class CaptureDevice {
  const CaptureDevice({required this.id, required this.label});

  final String id;
  final String label;
}

/// What this browser can actually do, checked at runtime.
class CaptureCapabilities {
  const CaptureCapabilities({
    required this.supported,
    required this.screen,
    required this.microphone,
    required this.camera,
    required this.audioFormats,
    required this.videoFormats,
  });

  const CaptureCapabilities.unsupported()
      : supported = false,
        screen = false,
        microphone = false,
        camera = false,
        audioFormats = const [],
        videoFormats = const [];

  final bool supported;
  final bool screen;
  final bool microphone;
  final bool camera;
  final List<String> audioFormats;
  final List<String> videoFormats;
}

/// Real information about the surface the user chose in the browser picker.
class ScreenShareInfo {
  const ScreenShareInfo({required this.label, required this.hasAudio, required this.width, required this.height});

  final String label;
  final bool hasAudio;
  final int width;
  final int height;
}

/// A container the MediaRecorder really supports in this browser.
class MediaFormat {
  const MediaFormat({required this.mimeType, required this.extension, required this.label, required this.video});

  final String mimeType;
  final String extension;
  final String label;
  final bool video;
}

/// A verified, finished capture ready to upload.
class RecordedCapture {
  const RecordedCapture({
    required this.bytes,
    required this.mimeType,
    required this.hasVideo,
    required this.duration,
    this.audioBytes,
    this.audioMimeType,
  });

  final Uint8List bytes;
  final String mimeType;
  final bool hasVideo;
  final Duration duration;
  final Uint8List? audioBytes;
  final String? audioMimeType;
}

/// A capture failure with enough detail for the UI to describe it honestly.
class CaptureFailure implements Exception {
  const CaptureFailure(
    this.message, {
    this.permissionDenied = false,
    this.deviceLost = false,
    this.unsupported = false,
  });

  final String message;
  final bool permissionDenied;
  final bool deviceLost;
  final bool unsupported;

  @override
  String toString() => message;
}

enum CapturePreview { screen, camera }

/// Lower third layout choices. All of them show only real streams.
enum MeetingLayout { presentation, speaker, gallery, audioOnly }

abstract class VirtualCaptureEngine {
  bool get supported;
  CaptureCapabilities get capabilities;

  bool get microphoneEnabled;
  bool get microphoneLive;
  bool get microphoneMuted;
  bool get cameraEnabled;
  bool get cameraLive;
  bool get screenActive;
  bool get screenLive;
  bool get screenHasAudio;
  String? get screenLabel;
  int get screenWidth;
  int get screenHeight;

  bool get recording;
  bool get paused;
  int get bytesRecorded;
  MediaFormat? get activeFormat;

  Future<List<CaptureDevice>> microphones();
  Future<List<CaptureDevice>> cameras();

  Future<void> startMicrophone({String? deviceId});
  Future<void> stopMicrophone();
  void setMicrophoneMuted(bool muted);

  Future<void> startCamera({String? deviceId});
  Future<void> stopCamera();

  Future<ScreenShareInfo> startScreenShare();
  Future<void> stopScreenShare();

  /// Real preview of [kind]. The stub returns an explanatory widget instead of
  /// pretending a stream exists.
  Widget preview(CapturePreview kind);

  double readMicrophoneLevel();
  double readSystemLevel();

  Future<void> startRecording({required bool includeVideo});
  void pauseRecording();
  void resumeRecording();
  Future<RecordedCapture> stopRecording();
  Future<void> discardRecording();

  /// Called when the user stops sharing from the browser's own bar.
  void setScreenShareEndedCallback(void Function()? callback);

  void dispose();
}
