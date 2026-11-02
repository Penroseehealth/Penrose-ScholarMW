import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'iframe_host_stub.dart' if (dart.library.js_interop) 'iframe_host_web.dart' as iframe_host;

/// Embeds the Voice Training Center classroom React app inside a web `<iframe>`.
///
/// Web-only: renders an iframe platform view pointing at [url]. On VM/mobile
/// builds (or when [enabled] is false) it renders [fallback] instead, so the
/// workspace never shows a blank viewport.
class LiveClassroomViewport extends StatelessWidget {
  final String url;
  final bool enabled;
  final Widget fallback;

  const LiveClassroomViewport({
    super.key,
    required this.url,
    required this.fallback,
    this.enabled = true,
  });

  void _onElementCreated(Object element) => iframe_host.configureLiveClassroomIframe(element, url);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !enabled) return fallback;
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: _onElementCreated,
    );
  }
}
