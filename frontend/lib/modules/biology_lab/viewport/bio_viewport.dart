import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'host_styling_stub.dart' if (dart.library.js_interop) 'host_styling_web.dart' as host_styling;

/// Host element id used by the platform view. Only one Biology Lab
/// viewport exists at a time (single route entry), so a fixed id is safe.
const String bioViewportHostId = 'penrose-bio-lab-host';

/// [BioLabViewport] owns only the DOM host element for the 3D engine.
///
/// Mirrors `chemistry_lab/viewport/lab_viewport.dart`: when the platform
/// view's element is created it is styled and [onHostReady] fires with its
/// id, at which point the provider runs `bridge.init(hostId:)`.
class BioLabViewport extends StatefulWidget {
  final bool enabled;
  final void Function(String hostId) onHostReady;
  final Widget fallback;

  const BioLabViewport({
    super.key,
    required this.enabled,
    required this.onHostReady,
    required this.fallback,
  });

  @override
  State<BioLabViewport> createState() => _BioLabViewportState();
}

class _BioLabViewportState extends State<BioLabViewport> {
  bool _notified = false;

  void _onElementCreated(Object element) {
    if (_notified) return;
    _notified = true;
    host_styling.styleLabHost(element, bioViewportHostId);
    widget.onHostReady(bioViewportHostId);
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !widget.enabled) return widget.fallback;
    return HtmlElementView.fromTagName(
      tagName: 'div',
      onElementCreated: _onElementCreated,
    );
  }
}
