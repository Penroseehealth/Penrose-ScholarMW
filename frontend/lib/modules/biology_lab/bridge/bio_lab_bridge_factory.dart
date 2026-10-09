import 'bio_lab_bridge.dart';
import 'bio_lab_bridge_stub.dart' if (dart.library.js_interop) 'bio_lab_bridge_web.dart' as impl;

/// Creates the platform-appropriate [BioLabBridge].
///
/// On Flutter web this returns the real `WebBioLabBridge` (Three.js adapter);
/// on VM/mobile it returns the stub that reports `isSupported == false` so
/// screens render the static fallback instead of a broken viewport.
BioLabBridge createBioLabBridge() => impl.createBioLabBridge();
