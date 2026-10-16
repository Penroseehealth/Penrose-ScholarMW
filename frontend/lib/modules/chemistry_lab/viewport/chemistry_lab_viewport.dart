import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'host_styling_stub.dart' if (dart.library.js_interop) 'host_styling_web.dart' as host_styling;

const String chemistryLabViewportHostId = 'penrose-chemistry-lab-host';

class ChemistryLabViewport extends StatefulWidget {
  final bool enabled;
  final ValueChanged<String> onHostReady;
  final Widget fallback;

  const ChemistryLabViewport({
    super.key,
    required this.enabled,
    required this.onHostReady,
    required this.fallback,
  });

  @override
  State<ChemistryLabViewport> createState() => _ChemistryLabViewportState();
}

class _ChemistryLabViewportState extends State<ChemistryLabViewport> {
  bool _notified = false;

  void _onElementCreated(Object element) {
    if (_notified) return;
    _notified = true;
    host_styling.styleChemistryLabHost(element, chemistryLabViewportHostId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onHostReady(chemistryLabViewportHostId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !widget.enabled) return widget.fallback;
    return HtmlElementView.fromTagName(tagName: 'div', onElementCreated: _onElementCreated);
  }
}
