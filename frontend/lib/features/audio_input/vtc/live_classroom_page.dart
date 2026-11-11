import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import 'live_classroom/fullscreen_host_stub.dart'
    if (dart.library.js_interop) 'live_classroom/fullscreen_host_web.dart'
    as fs_host;
import 'live_classroom/live_classroom_view.dart';
import 'vtc_theme.dart';

/// Where the built classroom app is served.
///
/// Defaults to the copy of the Voice Training Center build placed in
/// `web/voice-training/` (served verbatim by the FastAPI SPA handler). Override
/// for local dev with the Vite server, e.g.
/// `flutter run -d chrome --dart-define=VTC_LIVE_CLASSROOM_URL=http://localhost:5183/index.html`.
const String kLiveClassroomUrl = String.fromEnvironment(
  'VTC_LIVE_CLASSROOM_URL',
  defaultValue: '/voice-training/index.html',
);

/// The LiveKit room every Voice Training Center session joins.
///
/// One shared room today: there is no scheduling model behind the classroom
/// yet, so a per-session room name would be invented rather than real.
const String kLiveClassroomRoom = String.fromEnvironment(
  'VTC_LIVE_ROOM',
  defaultValue: 'vtc_live_classroom',
);

/// DOM id used so the browser Fullscreen API can target the iframe wrapper.
const String _kClassroomWrapperId = 'penrose-live-classroom-wrapper';

/// Builds the embed URL for the signed-in learner.
///
/// The Penrose access token is handed to the page so it can ask the backend for
/// a short-lived LiveKit token itself; the LiveKit secret never leaves the
/// server. The page moves the token into `sessionStorage` and rewrites its own
/// URL on load, so the JWT does not stay in view or in history. `name` and
/// `identity` let the classroom show the learner's real display name and keep a
/// stable participant identity.
String liveClassroomEmbedUrl({
  required String userName,
  required String token,
  String? identity,
  String room = kLiveClassroomRoom,
  String? apiOrigin,
}) {
  final uri = Uri.parse(kLiveClassroomUrl);
  final params = <String, String>{
    ...uri.queryParameters,
    'embed': '1',
    'room': room,
  };
  final name = userName.trim();
  if (name.isNotEmpty) params['name'] = name;
  final participant = identity?.trim() ?? '';
  if (participant.isNotEmpty) params['identity'] = participant;
  final jwt = token.trim();
  if (jwt.isNotEmpty) params['token'] = jwt;
  // The classroom may be served by the Flutter dev server rather than the
  // backend, so tell it where `/api/v1` actually lives. Omitted when the API is
  // already same-origin.
  final api = apiOrigin?.trim() ?? '';
  if (api.isNotEmpty) params['api'] = api;
  return uri.replace(queryParameters: params).toString();
}

/// Absolute API origin for the classroom, or null when it is same-origin.
///
/// `apiBaseUrl` is normally `/api/v1` (production, served by the backend) but
/// is an absolute URL during local web development. The embedded React app can
/// only resolve relative calls against its own origin, which is the Flutter
/// dev server, so the real origin has to be handed over explicitly.
String? liveClassroomApiOrigin() {
  final base = apiBaseUrl.trim();
  final uri = Uri.tryParse(base);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri.origin;
}

/// The Voice Training Center's Live Classroom tab.
///
/// When mounted via the VTC's immersive mode this widget fills the Flutter
/// route: the VTC header, sidebar, scenic backdrop, and all surrounding chrome
/// are hidden by [VoiceTrainingCenterPage.build]. This page therefore only owns
/// the session handoff and the iframe framing.
///
/// [onExit] is called when the user taps the discreet "back to VTC" control.
/// Pass null when the page is embedded inside a context that provides its own
/// exit mechanism.
///
/// Real browser fullscreen (Fullscreen API) is wired through
/// [fullscreen_host_web.dart]; on non-web builds it degrades gracefully to the
/// Flutter-route full-workspace mode.
class LiveClassroomPage extends StatefulWidget {
  const LiveClassroomPage({super.key, this.onExit});

  /// Called when the user requests to leave the Live Classroom and return to
  /// the Voice Training Center. When null, no exit control is rendered.
  final VoidCallback? onExit;

  @override
  State<LiveClassroomPage> createState() => _LiveClassroomPageState();
}

class _LiveClassroomPageState extends State<LiveClassroomPage> {
  /// Access token for the embedded classroom.
  ///
  /// Read once per signed-in session. Caching the null that is read while
  /// `AuthProvider.init()` is still signing in would leave the classroom
  /// permanently unauthenticated, so a fresh read happens on sign-in and after
  /// a manual reconnect.
  Future<String?>? _token;
  bool _signedIn = false;

  /// Remounts the iframe on reload; an iframe's `src` cannot be replaced in
  /// place, and a reconnect must ask the backend for a new room token.
  int _generation = 0;

  /// Tracks whether the browser is currently in fullscreen mode.
  bool _browserFullscreen = false;

  /// Whether the browser's Fullscreen API is available on this platform.
  final bool _fullscreenSupported = fs_host.isFullscreenSupported();

  /// Removes the fullscreen-change event listener when the widget is disposed.
  void Function()? _fullscreenDisposer;

  @override
  void initState() {
    super.initState();
    if (_fullscreenSupported) {
      _fullscreenDisposer = fs_host.onFullscreenChange((active) {
        if (mounted) setState(() => _browserFullscreen = active);
      });
    }
  }

  @override
  void dispose() {
    _fullscreenDisposer?.call();
    super.dispose();
  }

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

  void _reconnect() {
    setState(() {
      _signedIn = false;
      _token = null;
      _generation++;
    });
  }

  String? _identityOf(AuthProvider auth) {
    final id = auth.user?['id'];
    if (id == null) return null;
    return 'user_$id';
  }

  /// Toggles real browser fullscreen. When fullscreen is unavailable or
  /// refused, the method returns without changing the Flutter UI (the
  /// full-workspace fallback is already in place via VTC bypass mode).
  Future<void> _toggleBrowserFullscreen() async {
    if (!_fullscreenSupported) return;
    if (_browserFullscreen) {
      await fs_host.exitFullscreen();
    } else {
      await fs_host.requestFullscreen(_kClassroomWrapperId);
    }
    // State is updated by the fullscreenchange listener registered in initState.
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return FutureBuilder<String?>(
      future: _accessTokenFor(auth),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LiveClassroomNotice(
            icon: Icons.wifi_tethering_rounded,
            title: 'Preparing the live room',
            message: 'Getting your Penrose session ready for the classroom.',
            busy: true,
          );
        }

        final token = snapshot.data?.trim() ?? '';
        if (token.isEmpty) {
          return const _LiveClassroomNotice(
            icon: Icons.lock_outline_rounded,
            title: 'Sign in to join',
            message: 'The live classroom joins with your Penrose session. '
                'Sign in again and reopen this tab.',
          );
        }

        final url = liveClassroomEmbedUrl(
          userName: auth.userName,
          token: token,
          identity: _identityOf(auth),
          apiOrigin: liveClassroomApiOrigin(),
        );

        // The iframe wrapper is given an id so the Fullscreen API can target it
        // directly. The HtmlElementView itself does not expose an id.
        return Stack(
          children: [
            // --- The iframe, filling the entire space ---
            _ImmersiveClassroomFrame(
              wrapperId: _kClassroomWrapperId,
              child: LiveClassroomViewport(
                key: ValueKey<String>('$url#$_generation'),
                url: url,
                fallback: const _LiveClassroomNotice(
                  icon: Icons.desktop_windows_outlined,
                  title: 'Live Classroom runs in the browser',
                  message: 'Audio and video need a browser build of Penrose. '
                      'Open the web app to join the room.',
                ),
              ),
            ),

            // --- Discreet top-right control strip ---
            Positioned(
              top: 10,
              right: 12,
              child: _ClassroomControlStrip(
                room: kLiveClassroomRoom,
                fullscreenSupported: _fullscreenSupported,
                browserFullscreen: _browserFullscreen,
                onReconnect: _reconnect,
                onToggleFullscreen:
                    _fullscreenSupported ? _toggleBrowserFullscreen : null,
                onExit: widget.onExit,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Immersive frame
// ---------------------------------------------------------------------------

/// A transparent wrapper that fills its parent and carries a DOM id so the
/// Fullscreen API can target it on web. On non-web this is just a plain
/// container.
class _ImmersiveClassroomFrame extends StatelessWidget {
  const _ImmersiveClassroomFrame({
    required this.wrapperId,
    required this.child,
  });

  final String wrapperId;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.expand(child: child);
}

// ---------------------------------------------------------------------------
// Control strip
// ---------------------------------------------------------------------------

/// A minimal, translucent pill of controls that floats in the top-right corner
/// of the classroom workspace. It intentionally has low visual weight so it
/// does not compete with the room video grid.
class _ClassroomControlStrip extends StatelessWidget {
  const _ClassroomControlStrip({
    required this.room,
    required this.fullscreenSupported,
    required this.browserFullscreen,
    required this.onReconnect,
    this.onToggleFullscreen,
    this.onExit,
  });

  final String room;
  final bool fullscreenSupported;
  final bool browserFullscreen;
  final VoidCallback onReconnect;
  final VoidCallback? onExit;
  final Future<void> Function()? onToggleFullscreen;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: VtcPalette.headerBg.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: VtcPalette.border.withValues(alpha: 0.6)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 12,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Live indicator + room label
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: VtcPalette.liveGradient,
                  boxShadow: [
                    BoxShadow(
                      color: VtcPalette.successBright.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                room,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: VtcPalette.textMuted,
                  fontFamilyFallback: VtcType.fallback,
                ),
              ),
              const SizedBox(width: 6),

              // Reconnect
              _StripButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Reconnect the classroom',
                onPressed: onReconnect,
              ),

              // Fullscreen toggle (web only, hidden when API is unavailable)
              if (fullscreenSupported) ...[
                const SizedBox(width: 2),
                _StripButton(
                  icon: browserFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  tooltip: browserFullscreen
                      ? 'Exit fullscreen'
                      : 'Enter fullscreen',
                  onPressed: onToggleFullscreen != null
                      ? () => onToggleFullscreen!()
                      : null,
                ),
              ],

              // Exit to VTC (shown only when callback is provided)
              if (onExit != null) ...[
                const SizedBox(width: 2),
                _StripButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Return to Voice Training Center',
                  onPressed: onExit,
                ),
              ],
            ],
          ),
        ),
      );
}

class _StripButton extends StatelessWidget {
  const _StripButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: 17,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        color: VtcPalette.textSecondary,
        icon: Icon(icon),
      );
}

// ---------------------------------------------------------------------------
// Status / fallback notice panel
// ---------------------------------------------------------------------------

/// Centred, honest state panel: loading, signed-out and non-web fallbacks.
class _LiveClassroomNotice extends StatelessWidget {
  const _LiveClassroomNotice({
    required this.icon,
    required this.title,
    required this.message,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool busy;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GlassPanel(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: VtcPalette.electricBright),
                  )
                else
                  Icon(icon, size: 30, color: VtcPalette.electricBright),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: VtcType.sectionHeading(context).copyWith(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: VtcType.body(context).copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ),
        ),
      );
}
