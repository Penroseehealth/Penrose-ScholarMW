// Facade over the platform capture engine. Web gets a real implementation
// (getUserMedia/getDisplayMedia/MediaRecorder); tests and the VM get an inert
// stub that reports "unsupported" instead of pretending to capture.
import 'capture_engine_stub.dart' if (dart.library.js_interop) 'capture_engine_web.dart' as impl;

import 'capture_engine_types.dart';

export 'capture_engine_types.dart';

class VirtualCapture {
  VirtualCapture._();

  static VirtualCaptureEngine create() => impl.createVirtualCaptureEngine();
}
