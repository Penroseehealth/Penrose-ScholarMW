import 'lab_bridge.dart';
import 'lab_bridge_stub.dart' if (dart.library.js_interop) 'lab_bridge_web.dart' as impl;

/// Creates the platform-appropriate [LabBridge].
///
/// On Flutter web this returns the real `WebLabBridge` (Three.js adapter);
/// on VM/mobile it returns the stub that reports `isSupported == false` so
/// screens render the static fallback instead of a broken viewport.
LabBridge createLabBridge() => impl.createLabBridge();
