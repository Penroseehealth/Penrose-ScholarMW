import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'iframe_host_stub.dart' if (dart.library.js_interop) 'iframe_host_web.dart' as iframe_host;

/// Embeds the mathsdrill React application inside a web `<iframe>`.
///
/// Web-only: renders an iframe platform view pointing at [url]. On VM/mobile
/// builds (or when [enabled] is false) it renders [fallback] instead, so the
/// screen never shows a broken viewport.
class MathsdrillViewport extends StatelessWidget {
  final String url;
  final bool enabled;
  final Widget fallback;

  const MathsdrillViewport({
    super.key,
    required this.url,
    required this.fallback,
    this.enabled = true,
  });

  void _onElementCreated(Object element) => iframe_host.configureMathsdrillIframe(element, url);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !enabled) return fallback;
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: _onElementCreated,
    );
  }
}
