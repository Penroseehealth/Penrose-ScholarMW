import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'iframe_host_stub.dart' if (dart.library.js_interop) 'iframe_host_web.dart' as iframe_host;

/// Embeds the standalone biology laboratory environment (Three.js, walking
/// teacher avatar) inside a web `<iframe>`.
///
/// Web-only: renders an iframe platform view pointing at [url]. On VM/mobile
/// builds (or when [enabled] is false) it renders [fallback] instead, so the
/// screen never shows a broken viewport.
class BiologyLabEmbedViewport extends StatelessWidget {
  final String url;
  final bool enabled;
  final Widget fallback;

  const BiologyLabEmbedViewport({
    super.key,
    required this.url,
    required this.fallback,
    this.enabled = true,
  });

  void _onElementCreated(Object element) => iframe_host.configureBiologyLabIframe(element, url);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !enabled) return fallback;
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: _onElementCreated,
    );
  }
}

/// Registers [onExit] for exit requests posted by the embedded lab page's
/// bottom-left exit button. Returns a function that unregisters the listener.
void Function() onBioLabExitRequest(void Function() onExit) => iframe_host.listenForBioLabExit(onExit);
