import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Result of a LiveKit token request from the backend.
class LiveKitToken {
  final String token;
  final String url;
  final String roomName;
  final String identity;
  final int expiresIn;

  const LiveKitToken({
    required this.token,
    required this.url,
    required this.roomName,
    required this.identity,
    required this.expiresIn,
  });

  factory LiveKitToken.fromJson(Map<String, dynamic> json) => LiveKitToken(
        token: json['token'] as String,
        url: json['url'] as String,
        roomName: json['room_name'] as String,
        identity: json['identity'] as String,
        expiresIn: (json['expires_in'] as num?)?.toInt() ?? 3600,
      );
}

/// Client-side LiveKit service.
///
/// This service communicates with the FastAPI backend to obtain
/// short-lived access tokens. The LiveKit API secret NEVER reaches
/// this service — only JWT tokens are exchanged.
class LiveKitService {
  final ApiService _api;
  LiveKitToken? _cachedToken;
  Timer? _refreshTimer;

  LiveKitService({ApiService? api}) : _api = api ?? ApiService();

  /// Get the cached token or null.
  LiveKitToken? get currentToken => _cachedToken;

  /// Request a short-lived LiveKit access token from the backend.
  ///
  /// [roomName] — optional room name (defaults to user-specific room).
  /// [ttlSeconds] — token lifetime in seconds (60–86400, default 3600).
  Future<LiveKitToken?> requestToken({
    String? roomName,
    int ttlSeconds = 3600,
  }) async {
    try {
      final body = <String, dynamic>{
        'ttl_seconds': ttlSeconds,
      };
      if (roomName != null) body['room_name'] = roomName;

      final response = await _api.post('/livekit/token', body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _cachedToken = LiveKitToken.fromJson(data);
        _scheduleRefresh(_cachedToken!);
        return _cachedToken;
      }

      debugPrint('LiveKit token request failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('LiveKit token request error: $e');
      return null;
    }
  }

  /// Get the LiveKit WebSocket URL for a room (no secret involved).
  Future<String?> getRoomUrl(String roomName) async {
    try {
      final response = await _api.get('/livekit/room/$roomName');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['url'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Check LiveKit backend health (does not expose secrets).
  Future<bool> checkHealth() async {
    try {
      final response = await _api.get('/livekit/health');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['configured'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Schedule automatic token refresh before expiry.
  void _scheduleRefresh(LiveKitToken token) {
    _refreshTimer?.cancel();
    // Refresh at 80% of token lifetime
    final refreshIn = Duration(seconds: (token.expiresIn * 0.8).toInt());
    _refreshTimer = Timer(refreshIn, () async {
      await requestToken(roomName: token.roomName);
    });
  }

  /// Clear cached token and cancel refresh timer.
  void clearToken() {
    _cachedToken = null;
    _refreshTimer?.cancel();
  }

  void dispose() {
    _refreshTimer?.cancel();
  }
}
