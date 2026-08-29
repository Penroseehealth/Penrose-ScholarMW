import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import 'connectivity_manager.dart';
import 'context_service.dart';

/// A single chunk from the streaming AI response.
class StreamChunk {
  final String type; // 'chunk', 'done', 'error'
  final String content;
  final int? messageId;
  final String? sources;

  const StreamChunk({
    required this.type,
    required this.content,
    this.messageId,
    this.sources,
  });
}

/// Consumes SSE streaming from the backend AI chat endpoint.
class StreamingChatService {
  final ApiService _api;
  StreamSubscription<String>? _activeSubscription;

  StreamingChatService({ApiService? api}) : _api = api ?? ApiService();

  bool get isStreaming => _activeSubscription != null;

  /// Cancel the current stream (for interruption).
  void cancelCurrentStream() {
    _activeSubscription?.cancel();
    _activeSubscription = null;
  }

  /// Stream a chat message and yield chunks as they arrive.
  ///
  /// [message] — the user's text
  /// [sessionId] — the active chat session ID
  /// [agentType] — tutor, study_coach, writer, etc.
  /// [workspace] — current workspace state
  /// [fileIds] — uploaded file IDs
  /// [preferredResponseMode] — text, audio, visual, combined, interactive
  Stream<StreamChunk> streamChat({
    required String message,
    required int? sessionId,
    String agentType = 'tutor',
    WorkspaceState? workspace,
    List<String> fileIds = const [],
    String? preferredResponseMode,
    ConnectivityManager? connectivity,
  }) async* {
    cancelCurrentStream();

    // Offline guard
    if (connectivity != null && connectivity.isOffline) {
      yield const StreamChunk(
        type: 'error',
        content: 'offline',
      );
      return;
    }

    final body = <String, dynamic>{
      'message': message,
      'agent_type': agentType,
    };
    if (sessionId != null) body['session_id'] = sessionId;
    if (workspace != null && !workspace.isEmpty) {
      body['workspace'] = workspace.toJson();
    }
    if (fileIds.isNotEmpty) body['file_ids'] = fileIds;
    if (preferredResponseMode != null) {
      body['preferred_response_mode'] = preferredResponseMode;
    }

    try {
      final response = await _api.postStream('/ai/chat/stream', body: body);

      if (response.statusCode == 401) {
        yield const StreamChunk(
          type: 'error',
          content: 'auth',
        );
        return;
      }

      if (response.statusCode != 200) {
        yield const StreamChunk(
          type: 'error',
          content: 'Failed to connect to AI service',
        );
        return;
      }

      final completer = Completer<void>();
      _activeSubscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data.isEmpty) return;

            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final type = json['type']?.toString() ?? 'chunk';
              final content = json['content']?.toString() ?? '';

              _chunkController.add(StreamChunk(
                type: type,
                content: content,
                messageId: json['message_id'] as int?,
                sources: json['sources'] as String?,
              ));
            } catch (e) {
              debugPrint('SSE parse error: $e');
            }
          }
        },
        onDone: () {
          _activeSubscription = null;
          _chunkController.close();
          if (!completer.isCompleted) completer.complete();
        },
        onError: (e) {
          _activeSubscription = null;
          _chunkController.add(const StreamChunk(
            type: 'error',
            content: 'Stream error',
          ));
          _chunkController.close();
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Wait for the stream to complete
      await completer.future;
    } catch (e) {
      debugPrint('Streaming chat failed: $e');
      yield StreamChunk(type: 'error', content: 'Connection failed: $e');
    }
  }

  final _chunkController = StreamController<StreamChunk>.broadcast();

  /// Alternative: returns a broadcast stream of chunks for UI listening.
  Stream<StreamChunk> get chunkStream => _chunkController.stream;
}
