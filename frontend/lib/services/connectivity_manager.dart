import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';

/// Connection states for the application.
enum ConnectionState {
  online,
  connecting,
  reconnecting,
  offline,
}

/// Central connectivity manager that monitors internet availability,
/// provider reachability, and connection state transitions.
///
/// Provides:
/// - Continuous internet monitoring via periodic HTTP probes
/// - Provider health checking via /ai-orchestrator/health
/// - State transition callbacks (online→offline, offline→online)
/// - Pending request queue for offline question preservation
class ConnectivityManager extends ChangeNotifier {
  final ApiService _api;

  ConnectionState _state = ConnectionState.online;
  Timer? _probeTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;

  // State
  DateTime? _lastOnlineTime;
  DateTime? _lastOfflineTime;
  int _consecutiveFailures = 0;
  bool _aiAvailable = false;
  String _statusMessage = 'Checking connection...';

  // Pending requests
  final List<Map<String, dynamic>> _pendingQuestions = [];

  // Callbacks
  VoidCallback? _onTransitionOnline;
  VoidCallback? _onTransitionOffline;

  // Getters
  ConnectionState get state => _state;
  bool get isOnline => _state == ConnectionState.online;
  bool get isOffline => _state == ConnectionState.offline;
  bool get isConnecting => _state == ConnectionState.connecting || _state == ConnectionState.reconnecting;
  bool get aiAvailable => _aiAvailable;
  String get statusMessage => _statusMessage;
  DateTime? get lastOnlineTime => _lastOnlineTime;
  DateTime? get lastOfflineTime => _lastOfflineTime;
  List<Map<String, dynamic>> get pendingQuestions => List.unmodifiable(_pendingQuestions);

  ConnectivityManager({ApiService? api}) : _api = api ?? ApiService();

  /// Configure state transition callbacks.
  void configure({
    VoidCallback? onTransitionOnline,
    VoidCallback? onTransitionOffline,
  }) {
    _onTransitionOnline = onTransitionOnline;
    _onTransitionOffline = onTransitionOffline;
  }

  /// Start monitoring connectivity. Probes every [interval].
  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(interval, (_) => _probe());
    _probe(); // immediate first check
  }

  /// Stop monitoring.
  void stopMonitoring() {
    _probeTimer?.cancel();
    _reconnectTimer?.cancel();
  }

  /// Force an immediate connectivity check.
  Future<void> checkNow() async {
    await _probe();
  }

  // -----------------------------------------------------------------------
  // Probe logic
  // -----------------------------------------------------------------------

  Future<void> _probe() async {
    if (_disposed) return;

    // Simple connectivity check: hit the API server directly.
    // On web, the app is served from the same origin, so /health works.
    bool internetAvailable = false;
    try {
      final uri = kIsWeb ? Uri.parse('/health') : Uri.parse('http://localhost:8000/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      internetAvailable = response.statusCode == 200;
    } catch (_) {
      internetAvailable = false;
    }

    if (!internetAvailable) {
      _handleOffline();
      return;
    }

    // Internet is available — check AI provider health
    if (_state != ConnectionState.online) {
      _setState(ConnectionState.reconnecting);
    }

    try {
      final response = await _api.get('/ai-orchestrator/health');
      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(
          _parseResponse(response.body) ?? {},
        );
        _aiAvailable = data['online'] == true;
        _statusMessage = _aiAvailable ? 'AI services available' : 'AI providers temporarily unavailable';
        _handleOnline();
      } else {
        _aiAvailable = false;
        _statusMessage = 'Server responded with error ${response.statusCode}';
        _handleOnline(); // internet works, just AI providers might be down
      }
    } catch (_) {
      // Internet works but API server is down — still consider online
      _aiAvailable = false;
      _statusMessage = 'Connected but server unreachable';
      _handleOnline();
    }
  }

  Map<String, dynamic>? _parseResponse(String body) {
    try {
      return Map<String, dynamic>.from(jsonDecode(body));
    } catch (_) {
      return null;
    }
  }

  void _handleOnline() {
    _consecutiveFailures = 0;
    _lastOnlineTime = DateTime.now();

    if (_state != ConnectionState.online) {
      _setState(ConnectionState.online);
      _onTransitionOnline?.call();
      _retryPendingQuestions();
    }
  }

  void _handleOffline() {
    _consecutiveFailures++;

    // Require multiple consecutive failures before going offline (avoids
    // false positives on web where the first probe may fail during startup).
    if (_consecutiveFailures < 2) return;

    if (_state == ConnectionState.online) {
      _lastOfflineTime = DateTime.now();
      _setState(ConnectionState.offline);
      _onTransitionOffline?.call();
    } else if (_state == ConnectionState.offline && _consecutiveFailures > 5) {
      // Start trying to reconnect periodically
      _startReconnectTimer();
    }
  }

  void _startReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 15), () {
      if (_state == ConnectionState.offline && !_disposed) {
        _setState(ConnectionState.reconnecting);
        _probe();
      }
    });
  }

  void _setState(ConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // Pending questions (offline queue)
  // -----------------------------------------------------------------------

  /// Save a question that was asked while offline.
  void savePendingQuestion({
    required String message,
    required String agentType,
    int? sessionId,
    Map<String, dynamic>? workspace,
  }) {
    _pendingQuestions.add({
      'message': message,
      'agent_type': agentType,
      'session_id': sessionId,
      'workspace': workspace,
      'timestamp': DateTime.now().toIso8601String(),
    });
    notifyListeners();
  }

  /// Remove a pending question after it's been sent.
  void removePendingQuestion(int index) {
    if (index >= 0 && index < _pendingQuestions.length) {
      _pendingQuestions.removeAt(index);
      notifyListeners();
    }
  }

  /// Clear all pending questions.
  void clearPendingQuestions() {
    _pendingQuestions.clear();
    notifyListeners();
  }

  /// Retry all pending questions when coming back online.
  void _retryPendingQuestions() {
    if (_pendingQuestions.isEmpty) return;
    // Notify listeners so the AI tutor screen can pick up and retry
    notifyListeners();
  }

  /// Check if there are pending questions to retry.
  bool get hasPendingQuestions => _pendingQuestions.isNotEmpty;

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  @override
  void dispose() {
    _disposed = true;
    _probeTimer?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}
