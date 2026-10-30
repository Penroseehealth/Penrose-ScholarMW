// Non-web (VM/test) implementation. Every capture entry point reports that a
// browser is required so the UI never shows a fake live source or a fake save.
import 'package:flutter/widgets.dart';

import 'capture_engine_types.dart';

class _StubVirtualCaptureEngine implements VirtualCaptureEngine {
  @override
  bool get supported => false;

  @override
  CaptureCapabilities get capabilities => const CaptureCapabilities.unsupported();

  @override
  bool get microphoneEnabled => false;

  @override
  bool get microphoneLive => false;

  @override
  bool get microphoneMuted => false;

  @override
  bool get cameraEnabled => false;

  @override
  bool get cameraLive => false;

  @override
  bool get screenActive => false;

  @override
  bool get screenLive => false;

  @override
  bool get screenHasAudio => false;

  @override
  String? get screenLabel => null;

  @override
  int get screenWidth => 0;

  @override
  int get screenHeight => 0;

  @override
  bool get recording => false;

  @override
  bool get paused => false;

  @override
  int get bytesRecorded => 0;

  @override
  MediaFormat? get activeFormat => null;

  @override
  Future<List<CaptureDevice>> microphones() async => const <CaptureDevice>[];

  @override
  Future<List<CaptureDevice>> cameras() async => const <CaptureDevice>[];

  @override
  Future<void> startMicrophone({String? deviceId}) async {
    throw const CaptureFailure('Microphone capture needs a web browser.', unsupported: true);
  }

  @override
  Future<void> stopMicrophone() async {}

  @override
  void setMicrophoneMuted(bool muted) {}

  @override
  Future<void> startCamera({String? deviceId}) async {
    throw const CaptureFailure('Camera capture needs a web browser.', unsupported: true);
  }

  @override
  Future<void> stopCamera() async {}

  @override
  Future<ScreenShareInfo> startScreenShare() async {
    throw const CaptureFailure('Screen capture needs a web browser.', unsupported: true);
  }

  @override
  Future<void> stopScreenShare() async {}

  @override
  Widget preview(CapturePreview kind) => Container(
        color: const Color(0xFF071632),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Text(
          'Live preview needs a web browser.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF8296BC)),
        ),
      );

  @override
  double readMicrophoneLevel() => 0;

  @override
  double readSystemLevel() => 0;

  @override
  Future<void> startRecording({required bool includeVideo}) async {
    throw const CaptureFailure('Recording needs a web browser.', unsupported: true);
  }

  @override
  void pauseRecording() {}

  @override
  void resumeRecording() {}

  @override
  Future<RecordedCapture> stopRecording() async {
    throw const CaptureFailure('Recording needs a web browser.', unsupported: true);
  }

  @override
  Future<void> discardRecording() async {}

  @override
  void setScreenShareEndedCallback(void Function()? callback) {}

  @override
  void dispose() {}
}

VirtualCaptureEngine createVirtualCaptureEngine() => _StubVirtualCaptureEngine();
