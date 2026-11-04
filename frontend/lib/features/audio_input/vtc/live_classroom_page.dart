import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
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
/// The classroom itself is the React application, embedded so it keeps its own
/// responsive video grid, board and controls. This page owns the session
/// handoff and the framing, not the room state: connection status, participant
/// count and hand raising are reported from the real LiveKit room inside the
/// frame rather than duplicated here.
class LiveClassroomPage extends StatefulWidget {
  const LiveClassroomPage({super.key});

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

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: _ClassroomFrame(
            room: kLiveClassroomRoom,
            onReconnect: _reconnect,
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
        );
      },
    );
  }
}

/// Dark framed surface around the classroom, with the room label and a
/// reconnect action. Deliberately does not claim a connection state of its
/// own — the classroom reports that from the real room.
class _ClassroomFrame extends StatelessWidget {
  const _ClassroomFrame({
    required this.room,
    required this.onReconnect,
    required this.child,
  });

  final String room;
  final VoidCallback onReconnect;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: VtcPalette.border.withValues(alpha: 0.9)),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [VtcPalette.card, VtcPalette.workspace],
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, 16)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ClassroomToolbar(room: room, onReconnect: onReconnect),
              Expanded(child: child),
            ],
          ),
        ),
      );
}

class _ClassroomToolbar extends StatelessWidget {
  const _ClassroomToolbar({required this.room, required this.onReconnect});

  final String room;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final showRoom = constraints.maxWidth >= 420;
          final showHint = constraints.maxWidth >= 860;
          return Container(
            padding: EdgeInsets.symmetric(horizontal: showHint ? 16 : 12, vertical: 8),
            decoration: const BoxDecoration(
              color: VtcPalette.headerBg,
              border: Border(bottom: BorderSide(color: VtcPalette.divider)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: VtcPalette.liveGradient,
                    boxShadow: [
                      BoxShadow(color: VtcPalette.successBright.withValues(alpha: 0.55), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  'Live Classroom',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: VtcPalette.textPrimary,
                    fontFamilyFallback: VtcType.fallback,
                  ),
                ),
                if (showRoom) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Room · $room',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: VtcPalette.textMuted,
                          fontFamilyFallback: VtcType.fallback,
                        ),
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (showHint) ...[
                  const Text(
                    'Microphone and camera use this browser\'s permissions.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: VtcPalette.textMuted,
                      fontFamilyFallback: VtcType.fallback,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                IconButton(
                  onPressed: onReconnect,
                  tooltip: 'Reconnect the classroom',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  color: VtcPalette.textSecondary,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          );
        },
      );
}

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
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: VtcPalette.electricBright),
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
