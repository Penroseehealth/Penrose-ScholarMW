import 'package:web/web.dart' as web;

/// Configures the platform-view `<iframe>` host for the mathsdrill embed.
///
/// Web-only (uses `package:web`); selected by the conditional import in
/// `mathsdrill_viewport.dart` so VM/mobile builds and tests never see
/// `dart:js_interop`.
void configureMathsdrillIframe(Object element, String url) {
  final frame = element as web.HTMLIFrameElement;
  frame
    ..src = url
    ..title = 'mathsdrill'
    ..setAttribute('allow', 'clipboard-read; clipboard-write; fullscreen');
  frame.style
    ..setProperty('border', 'none')
    ..width = '100%'
    ..height = '100%';
}
