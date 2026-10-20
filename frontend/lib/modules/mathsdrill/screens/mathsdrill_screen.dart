import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../providers/auth_provider.dart';
import '../viewport/mathsdrill_viewport.dart';

/// Where the mathsdrill React app is served.
///
/// Defaults to the copy of the mathsdrill build placed in `web/mathsdrill/`
/// (served verbatim by the FastAPI SPA handler). Override for local dev with
/// the Vite server, e.g.
/// `flutter run -d chrome --dart-define=MATHSDRILL_URL=http://localhost:5173/index.html`.
const String kMathsdrillUrl = String.fromEnvironment(
  'MATHSDRILL_URL',
  defaultValue: '/mathsdrill/index.html',
);

/// Appends the signed-in user's name so the mathsdrill welcome gate is skipped.
///
/// mathsdrill reads `?student=<name>` on load and seeds its local student, so the
/// embedded app goes straight to the drill instead of asking for a name again.
String mathsdrillEmbedUrl(String userName) {
  final name = userName.trim();
  if (name.isEmpty) return kMathsdrillUrl;
  final uri = Uri.parse(kMathsdrillUrl);
  return uri.replace(queryParameters: {...uri.queryParameters, 'student': name}).toString();
}

/// Hosts the mathsdrill practice app (`/mathsdrill`) inside Penrose.
class MathsdrillScreen extends StatelessWidget {
  const MathsdrillScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final userName = context.watch<AuthProvider>().userName;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/student'),
          tooltip: 'Back to Dashboard',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calculate_rounded, color: t.teal, size: 20),
            const SizedBox(width: 8),
            Text('Mathsdrill', style: TextStyle(color: t.textPrimary, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => context.go('/mathsdrill/progress'),
            tooltip: 'Stored Progress',
          ),
        ],
      ),
      body: MathsdrillViewport(
        url: mathsdrillEmbedUrl(userName),
        fallback: const _MathsdrillFallback(),
      ),
    );
  }
}

class _MathsdrillFallback extends StatelessWidget {
  const _MathsdrillFallback();

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calculate_rounded, size: 48, color: t.textMuted),
            const SizedBox(height: 16),
            Text(
              'Mathsdrill',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'The mathsdrill practice app runs in the browser. Open $kMathsdrillUrl on a web build to use it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: t.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
