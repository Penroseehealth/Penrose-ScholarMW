import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/theme/theme_colors.dart';
import 'stem_text.dart';

/// Reveals a reply the way a person types it: one character at a time, slowly
/// and naturally, with pauses that follow grammar and punctuation.
/// Questions, exclamations, commas, periods get appropriate hesitations
/// so it reads conversationally rather than mechanically.
class TypewriterRenderer extends StatefulWidget {
  final String content;
  final TextStyle? style;
  final VoidCallback? onComplete;

  /// Base reveal speed hint (slower for more natural typing).
  final Duration charDuration;

  /// When false the whole string is shown immediately.
  final bool animate;

  const TypewriterRenderer({
    super.key,
    required this.content,
    this.style,
    this.onComplete,
    this.charDuration = const Duration(milliseconds: 35),
    this.animate = true,
  });

  @override
  State<TypewriterRenderer> createState() => _TypewriterRendererState();
}

class _TypewriterRendererState extends State<TypewriterRenderer> with SingleTickerProviderStateMixin {
  static const double _baseRate = 28; // slower, more natural typing
  static const double _maxRate = 120; // gentle acceleration if streaming fast
  static const double _backlogFull = 200;

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  int _revealed = 0;
  double _hold = 0; // seconds of remaining pause
  double _backlog = 0;
  String _source = '';
  int _completedFor = -1;

  @override
  void initState() {
    super.initState();
    _source = widget.content;
    _revealed = widget.animate ? 0 : widget.content.length;
    _ticker = createTicker(_onTick);
    if (widget.animate && _revealed < widget.content.length) {
      _ticker.start();
    } else if (_revealed >= widget.content.length) {
      _scheduleComplete();
    }
  }

  @override
  void didUpdateWidget(TypewriterRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content == widget.content) return;

    final restarted = !widget.content.startsWith(_source) || widget.content.length < _source.length;
    _source = widget.content;

    if (!widget.animate) {
      _revealed = widget.content.length;
      _ticker.stop();
      _scheduleComplete();
      return;
    }
    if (restarted) {
      _revealed = 0;
      _hold = 0;
      _backlog = 0;
      _completedFor = -1;
      _last = Duration.zero;
    }
    if (_revealed < widget.content.length) {
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    } else {
      _scheduleComplete();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.016 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;

    final target = widget.content.length;
    if (_revealed >= target) {
      _ticker.stop();
      _scheduleComplete();
      return;
    }

    if (_hold > 0) {
      _hold -= dt;
      return;
    }

    final pending = target - _revealed;
    _backlog = _backlog + (pending - _backlog) * (dt * 2.5).clamp(0.0, 1.0);
    final boost = (_backlog / _backlogFull).clamp(0.0, 1.0);
    final rate = _baseRate + (_maxRate - _baseRate) * boost * boost;

    var step = (rate * dt).floor();
    if (step < 1) {
      // Sub-character frames still need to advance at low frame rates.
      if (dt >= 1 / rate) step = 1;
    }
    if (step <= 0) return;

    final end = (_revealed + step).clamp(0, target);
    var pause = 0.0;
    for (var i = _revealed; i < end; i++) {
      pause += _pauseAfter(widget.content[i]);
    }
    final wasComplete = _revealed >= target;
    setState(() => _revealed = end);
    _hold = pause;
    if (!wasComplete && _revealed >= target) {
      _ticker.stop();
      _scheduleComplete();
    }
  }

  /// Hesitation (seconds) to insert after a character, following grammar and punctuation
  /// so questions/exclamations/commas/periods sound naturally paced.
  double _pauseAfter(String ch) {
    switch (ch) {
      case '?':
        return 0.28; // question needs a tiny thoughtful pause
      case '!':
        return 0.24; // exclamation
      case '.':
        return 0.22; // end of sentence
      case ';':
        return 0.16;
      case ':':
        return 0.14;
      case ',':
        return 0.12;
      case ')':
      case ']':
      case '}':
        return 0.06;
      case '\n':
        return 0.18;
      default:
        return 0;
    }
  }

  void _scheduleComplete() {
    if (_completedFor == widget.content.length) return;
    _completedFor = widget.content.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _revealed >= widget.content.length ? widget.content : widget.content.substring(0, _revealed);
    return StemText(
      shown,
      style: widget.style ?? TextStyle(color: context.colors.textPrimary, fontSize: 14, height: 1.6),
      selectable: true,
    );
  }
}
