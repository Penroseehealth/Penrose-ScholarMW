import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Configures the platform-view `<iframe>` host for the biology lab embed.
///
/// Web-only (uses `package:web`); selected by the conditional import in
/// `biology_lab_viewport.dart` so VM/mobile builds and tests never see
/// `dart:js_interop`.
void configureBiologyLabIframe(Object element, String url) {
  final frame = element as web.HTMLIFrameElement;
  frame
    ..src = url
    ..title = 'biology-lab'
    ..setAttribute('allow', 'fullscreen');
  frame.style
    ..setProperty('border', 'none')
    ..width = '100%'
    ..height = '100%';
}

/// Invokes [onExit] when the embedded lab page posts an exit request
/// (`window.parent.postMessage('penrose-bio-lab-exit', '*')` from its
/// bottom-left exit button).
///
/// Returns a function that removes the listener.
void Function() listenForBioLabExit(void Function() onExit) {
  final sub = web.window.onMessage.listen((event) {
    final data = event.data;
    if (data != null && data.isA<JSString>() && (data as JSString).toDart == 'penrose-bio-lab-exit') {
      onExit();
    }
  });
  return () {
    sub.cancel();
  };
}
