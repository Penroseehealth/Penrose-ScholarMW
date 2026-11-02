import 'package:web/web.dart' as web;

/// Configures the platform-view `<iframe>` that hosts the live classroom.
///
/// The classroom needs the microphone and camera, and plays remote audio
/// without a tap, so those permissions are delegated explicitly. The iframe is
/// same-origin with Penrose, which lets the embedded app call
/// `/api/v1/livekit/token` with the session token handed over in the query.
void configureLiveClassroomIframe(Object element, String url) {
  final frame = element as web.HTMLIFrameElement;
  frame
    ..src = url
    ..title = 'Penrose live classroom'
    ..setAttribute('allow', 'camera; microphone; autoplay; display-capture; clipboard-write; fullscreen')
    ..setAttribute('allowfullscreen', 'true');
  frame.style
    ..setProperty('border', 'none')
    ..setProperty('display', 'block')
    ..width = '100%'
    ..height = '100%';
}
