import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import 'live_classroom/live_classroom_view.dart';

/// Built React classroom application.
const String kLiveClassroomUrl = String.fromEnvironment(
  'VTC_LIVE_CLASSROOM_URL',
  defaultValue: '/voice-training/index.html',
);

/// Shared LiveKit room.
const String kLiveClassroomRoom = String.fromEnvironment(
  'VTC_LIVE_ROOM',
  defaultValue: 'vtc_live_classroom',
);

/// Creates the authenticated classroom URL.
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

  final api = apiOrigin?.trim() ?? '';
  if (api.isNotEmpty) params['api'] = api;

  return uri.replace(queryParameters: params).toString();
}

/// Resolves the API origin for the embedded React application.
String? liveClassroomApiOrigin() {
  final uri = Uri.tryParse(apiBaseUrl.trim());

  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }

  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return null;
  }

  return uri.origin;
}

/// Full-size Voice Training Center Live Classroom.
class LiveClassroomPage extends StatefulWidget {
  const LiveClassroomPage({super.key});

  @override
  State<LiveClassroomPage> createState() => _LiveClassroomPageState();
}

class _LiveClassroomPageState extends State<LiveClassroomPage> {
  Future<String?>? _token;
  bool _signedIn = false;

  int _generation = 0;

  /// Immersive mode expands the classroom to the complete available
  /// Flutter viewport and hides this page's own floating controls.
  bool _immersive = false;

  Future<String?> _accessTokenFor(AuthProvider auth) {
    if (!auth.isAuthenticated) {
      _signedIn = false;
      _token ??= Future<String?>.value();
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

  void _toggleImmersive() {
    setState(() {
      _immersive = !_immersive;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: FutureBuilder<String?>(
            future: _accessTokenFor(auth),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _ClassroomNotice(
                  icon: Icons.wifi_tethering_rounded,
                  title: 'Preparing the live room',
                  message: 'Getting your Penrose session ready.',
                  busy: true,
                );
              }

              final token = snapshot.data?.trim() ?? '';

              if (token.isEmpty) {
                return const _ClassroomNotice(
                  icon: Icons.lock_outline_rounded,
                  title: 'Sign in to join',
                  message:
                      'The live classroom requires your Penrose session. '
                      'Sign in again and reopen this tab.',
                );
              }

              final url = liveClassroomEmbedUrl(
                userName: auth.userName,
                token: token,
                identity: _identityOf(auth),
                apiOrigin: liveClassroomApiOrigin(),
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  /// Actual React classroom.
                  /// No padding, border, header or decorative frame.
                  Positioned.fill(
                    child: LiveClassroomViewport(
                      key: ValueKey<String>('$url#$_generation'),
                      url: url,
                      fallback: const _ClassroomNotice(
                        icon: Icons.desktop_windows_outlined,
                        title: 'Browser required',
                        message:
                            'Audio and video require the browser version '
                            'of Penrose ScholarMW.',
                      ),
                    ),
                  ),

                  /// Floating controls are hidden in immersive mode.
                  if (!_immersive)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _FloatingClassroomControls(
                        onReconnect: _reconnect,
                        onExpand: _toggleImmersive,
                      ),
                    ),

                  /// Small exit control when immersive mode is active.
                  if (_immersive)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Material(
                        color: const Color(0xDD151923),
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          onPressed: _toggleImmersive,
                          tooltip: 'Exit immersive presentation',
                          icon: const Icon(
                            Icons.fullscreen_exit_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Minimal floating controls.
class _FloatingClassroomControls extends StatelessWidget {
  const _FloatingClassroomControls({
    required this.onReconnect,
    required this.onExpand,
  });

  final VoidCallback onReconnect;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xDD151923),
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onReconnect,
            tooltip: 'Reconnect classroom',
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: onExpand,
            tooltip: 'Expand classroom',
            icon: const Icon(
              Icons.fullscreen_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading, authentication and fallback states.
class _ClassroomNotice extends StatelessWidget {
  const _ClassroomNotice({
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
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF10141E),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const CircularProgressIndicator()
                else
                  Icon(
                    icon,
                    size: 36,
                    color: const Color(0xFF65A9FF),
                  ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFFB8C1D1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
