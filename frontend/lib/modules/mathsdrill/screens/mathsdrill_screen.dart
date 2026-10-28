import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../screens/home/app_drawer.dart';
import '../../../services/api_service.dart';
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

/// Builds the embed URL for [userName], carrying the session token.
///
/// mathsdrill reads `?student=<name>` on load and seeds its local student, so
/// the embedded app goes straight to the drill instead of asking for a name
/// again. `?token=<jwt>` lets its chat call the authenticated AI solver with
/// the *same* signed-in session; the page scrubs the token from its URL as
/// soon as it has read it, so it never sits in an address bar or in history.
String mathsdrillEmbedUrl(String userName, [String? token]) {
  final name = userName.trim();
  final uri = Uri.parse(kMathsdrillUrl);
  final params = <String, String>{...uri.queryParameters};
  if (name.isNotEmpty) params['student'] = name;
  final jwt = token?.trim() ?? '';
  if (jwt.isNotEmpty) params['token'] = jwt;
  return uri.replace(queryParameters: params).toString();
}

/// Hosts the mathsdrill practice app (`/mathsdrill`) inside Penrose.
class MathsdrillScreen extends StatefulWidget {
  const MathsdrillScreen({super.key});

  @override
  State<MathsdrillScreen> createState() => _MathsdrillScreenState();
}

class _MathsdrillScreenState extends State<MathsdrillScreen> {
  /// Opens the navigation drawer from the hamburger in the app bar.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Access token for the embedded chat.
  ///
  /// Read once per signed-in session. A `late final` would cache the null that
  /// is read while `AuthProvider.init()` is still signing in, and the embedded
  /// app would then never receive a session. Cleared on sign-out so the next
  /// session reads a fresh token.
  Future<String?>? _token;
  bool _signedIn = false;

  Future<String?> _accessTokenFor(AuthProvider auth) {
    if (!auth.isAuthenticated) {
      _signedIn = false;
      _token ??= Future<String?>.value(); // stable identity: no rebuild loop
      return _token!;
    }
    if (!_signedIn || _token == null) {
      _signedIn = true;
      _token = ApiService().accessToken;
    }
    return _token!;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    final auth = context.watch<AuthProvider>();
    final userName = auth.userName;
    return FutureBuilder<String?>(
      future: _accessTokenFor(auth),
      builder: (context, snap) {
        final url = snap.connectionState == ConnectionState.done
            ? mathsdrillEmbedUrl(userName, snap.data)
            : null;
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: t.background,
          drawer: const AppDrawer(),
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
                // Σ in place of the old calculator glyph — the sum sign itself
                Text(
                  'Σ',
                  style: TextStyle(
                    color: t.teal,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                // Hamburger in place of the old "Mathsdrill" header text: it opens
                // the navigation drawer now that the workspace is full-screen.
                IconButton(
                  icon: const Icon(Icons.menu_rounded, size: 22),
                  color: t.textPrimary,
                  tooltip: 'Navigation menu',
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
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
          body: url == null
              // read the session first, so the app is fetched once with its
              // token already in the URL instead of being loaded twice
              ? Center(child: CircularProgressIndicator(color: t.teal))
              : MathsdrillViewport(
                  // keying on the url recreates the platform view when the url
                  // changes (the iframe's src cannot be updated in place)
                  key: ValueKey<String>(url),
                  url: url,
                  fallback: const _MathsdrillFallback(),
                ),
        );
      },
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
            Text(
              'Σ',
              style: TextStyle(
                  fontSize: 48, fontWeight: FontWeight.w700, color: t.teal),
            ),
            const SizedBox(height: 16),
            Text(
              'Mathsdrill',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary),
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
