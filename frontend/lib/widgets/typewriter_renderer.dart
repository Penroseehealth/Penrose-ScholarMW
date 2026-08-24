import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/theme_colors.dart';
import 'stem_text.dart';

class TypewriterRenderer extends StatefulWidget {
  final String content;
  final TextStyle? style;
  final VoidCallback? onComplete;
  final Duration charDuration;

  const TypewriterRenderer({
    super.key,
    required this.content,
    this.style,
    this.onComplete,
    this.charDuration = const Duration(milliseconds: 8),
  });

  @override
  State<TypewriterRenderer> createState() => _TypewriterRendererState();
}

class _TypewriterRendererState extends State<TypewriterRenderer> {
  String _displayed = '';
  Timer? _timer;
  int _charIndex = 0;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(TypewriterRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _timer?.cancel();
      _charIndex = 0;
      _displayed = '';
      _isComplete = false;
      _startTyping();
    }
  }

  void _startTyping() {
    final chars = widget.content.split('');
    _timer = Timer.periodic(widget.charDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_charIndex < chars.length) {
        final chunkSize = _getChunkSize(chars, _charIndex);
        final end = (_charIndex + chunkSize).clamp(0, chars.length);
        setState(() {
          _displayed += chars.sublist(_charIndex, end).join();
          _charIndex = end;
        });
      } else {
        timer.cancel();
        if (!_isComplete) {
          _isComplete = true;
          widget.onComplete?.call();
        }
      }
    });
  }

  int _getChunkSize(List<String> chars, int index) {
    if (index >= chars.length) return 1;
    final ch = chars[index];
    if (ch == '\n') return 3;
    if (ch == '.' || ch == '!' || ch == '?') return 2;
    if (ch == ' ') return 2;
    return 3;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StemText(
        _displayed,
        style: widget.style ?? TextStyle(color: context.colors.textPrimary, fontSize: 14, height: 1.6),
        selectable: true,
      );
}
