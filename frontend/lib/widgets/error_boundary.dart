import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/theme/theme_colors.dart';

/// Posts a description of a client-side failure to the backend so browser-only
/// errors end up in the server log. Any failure in the reporter is ignored.
Future<void> reportClientError(String source, Object error, StackTrace? stack) async {
  try {
    final buffer = StringBuffer('[DART-$source] ')
      ..writeln(error.toString())
      ..writeln('URL=${Uri.base}');
    if (stack != null) buffer.writeln(stack.toString());
    await http.post(
      Uri.base.resolve('/__diag'),
      body: buffer.toString(),
      headers: const <String, String>{'Content-Type': 'text/plain'},
    );
  } catch (_) {}
}

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stack)? errorBuilder;
  final VoidCallback? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();

  static void of(BuildContext context) {
    final state = context.findAncestorStateOfType<_ErrorBoundaryState>();
    if (state != null) {
      state.reset();
    }
  }
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  void reset() => setState(() {
        _error = null;
        _stackTrace = null;
      });

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder != null
          ? widget.errorBuilder!(_error!, _stackTrace)
          : _DefaultErrorWidget(
              error: _error!,
              stackTrace: _stackTrace,
              onRetry: reset,
            );
    }

    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    FlutterError.onError = (details) {
      unawaited(reportClientError('flutter', details.exception, details.stack));
      if (mounted) {
        setState(() {
          _error = details.exception;
          _stackTrace = details.stack;
        });
        widget.onError?.call();
      }
    };
  }
}

/// Full-screen fallback that does NOT depend on the app's theme or the
/// surrounding `MaterialApp` (this widget is rendered *above* it), so it must
/// provide its own `MaterialApp`, `Directionality` and opaque background.
class _DefaultErrorWidget extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;

  const _DefaultErrorWidget({
    required this.error,
    this.stackTrace,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final message = error.toString();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0A14),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.error_outline_rounded, size: 44, color: Color(0xFFFF8A8A)),
                  const SizedBox(height: 12),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFEDEDF2)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message.length > 400 ? '${message.substring(0, 400)}...' : message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFFB8B8C4)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reload'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScreenErrorFallback extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ScreenErrorFallback({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'An unexpected error occurred.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: colors.error.withAlpha(150)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.textMuted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
