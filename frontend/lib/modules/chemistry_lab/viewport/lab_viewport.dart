import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'host_styling_stub.dart' if (dart.library.js_interop) 'host_styling_web.dart' as host_styling;

/// Host element id used by the platform view. Only one Chemistry Lab
/// viewport exists at a time (single route entry), so a fixed id is safe
/// and lets the JS side address the DOM host without extra bookkeeping.
const String labViewportHostId = 'penrose-chem-lab-host';

/// [LabViewport] owns only the DOM host element for the 3D engine.
///
/// When the platform view's element is created it is styled and
/// [onHostReady] fires with its id, at which point the caller (the lab
/// provider) runs `bridge.init(hostId:)`. The bridge itself is owned and
/// disposed by the provider, not by this widget, so lifecycle has exactly
/// one owner.
///
/// On non-web platforms this builds [fallback] instead — never touch
/// `HtmlElementView` outside the `kIsWeb` guard, because its factory throws
/// `UnimplementedError` on IO platforms. DOM-specific styling lives behind
/// a conditional import so VM builds and tests never pull in `package:web`.
class LabViewport extends StatefulWidget {
  final bool enabled;
  final void Function(String hostId) onHostReady;
  final Widget fallback;

  const LabViewport({
    super.key,
    required this.enabled,
    required this.onHostReady,
    required this.fallback,
  });

  @override
  State<LabViewport> createState() => _LabViewportState();
}

class _LabViewportState extends State<LabViewport> {
  bool _notified = false;

  void _onElementCreated(Object element) {
    if (_notified) return;
    _notified = true;
    // Style the host before Flutter attaches it to the DOM (web-only impl).
    host_styling.styleLabHost(element, labViewportHostId);
    widget.onHostReady(labViewportHostId);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !widget.enabled) return widget.fallback;
    return HtmlElementView.fromTagName(
      tagName: 'div',
      onElementCreated: _onElementCreated,
    );
  }
}
