import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_colors.dart';
import '../../modules/biology_real_lab/viewport/biology_lab_viewport.dart';

const Color _bioGreen = Color(0xFF10B981);
const Color _bioGreenGlow = Color(0x2210B981);

/// Where the standalone biology laboratory (Three.js, walking teacher) is served.
///
/// Defaults to the copy of the lab runtime placed in `web/biology_lab/`
/// (served verbatim by the FastAPI SPA handler). Override for local dev with
/// the node server, e.g.
/// `flutter run -d chrome --dart-define=BIO_LAB_URL=http://localhost:7456/index.html`.
const String kBioLabUrl = String.fromEnvironment(
  'BIO_LAB_URL',
  defaultValue: '/biology_lab/index.html',
);

/// Hosts the real biology lab environment (`/bio-real-lab`) full-screen.
///
/// Routed outside the `HomeShell` so no sidebar is rendered. The only chrome
/// is the exit button rendered inside the lab page itself (bottom-left of the
/// scene), which posts a message that [_BiologyRealLabScreenState] handles.
class BiologyRealLabScreen extends StatefulWidget {
  /// Science-module id of the practical to start on load (e.g. `osmosis`,
  /// `enzyme`, `photosynthesis`). Null opens the lab in its default free-roam
  /// state. Passed by the Virtual Biology Lab's "Start Simulation" button.
  final String? experimentId;

  const BiologyRealLabScreen({super.key, this.experimentId});

  @override
  State<BiologyRealLabScreen> createState() => _BiologyRealLabScreenState();
}

class _BiologyRealLabScreenState extends State<BiologyRealLabScreen> {
  void Function() _removeExitListener = () {};

  /// The lab URL with the optional `?experiment=<id>` deep-link appended.
  String get _labUrl {
    final id = widget.experimentId;
    if (id == null || id.isEmpty) return kBioLabUrl;
    final sep = kBioLabUrl.contains('?') ? '&' : '?';
    return '$kBioLabUrl${sep}experiment=$id';
  }

  @override
  void initState() {
    super.initState();
    _removeExitListener = onBioLabExitRequest(_exitLab);
  }

  void _exitLab() {
    if (mounted) context.go('/dashboard');
  }

  @override
  void dispose() {
    _removeExitListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B0F14),
        body: Stack(
          children: [
            Positioned.fill(
              child: BiologyLabEmbedViewport(
                url: _labUrl,
                fallback: const _BioLabFallback(),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: _ExitButton(onExit: _exitLab),
              ),
            ),
          ],
        ),
      );
}

class _ExitButton extends StatefulWidget {
  final VoidCallback onExit;

  const _ExitButton({required this.onExit});

  @override
  State<_ExitButton> createState() => _ExitButtonState();
}

class _ExitButtonState extends State<_ExitButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onExit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _hovered ? t.errorMuted : t.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hovered ? t.error : t.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.45 : 0.3),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.close_rounded,
            size: 24,
            color: _hovered ? t.error : t.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _BioLabFallback extends StatelessWidget {
  const _BioLabFallback();

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _bioGreenGlow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.view_in_ar_rounded, size: 36, color: _bioGreen),
            ),
            const SizedBox(height: 20),
            Text(
              'Real Biology Lab',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: t.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'The laboratory environment runs in the browser. Open $kBioLabUrl on a web build to use it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: t.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
