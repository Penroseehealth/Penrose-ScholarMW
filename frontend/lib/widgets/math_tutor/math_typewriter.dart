import 'dart:async';

import 'package:flutter/material.dart';

import 'math_tex.dart';

/// Splits a line of LaTeX into revealable tokens.
///
/// The tutor writes one token at a time so the student watches the expression
/// build up, but mathematical notation cannot be typeset half-finished. Every
/// token here is a whole command (with its brace groups), a superscript or
/// subscript (with its argument) or a single character, which guarantees that
/// any prefix of the token list is still valid LaTeX.
class LatexReveal {
  const LatexReveal._();

  /// Operators earn a longer, more deliberate pause when written.
  static const Set<String> _operators = <String>{
    '+',
    '-',
    '=',
    '<',
    '>',
    r'\times',
    r'\div',
    r'\cdot',
    r'\pm',
    r'\le',
    r'\ge',
  };

  static bool _isLetter(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  /// Index just past the balanced ``{ ... }`` group starting at [start].
  static int _groupEnd(String text, int start) {
    var depth = 0;
    var index = start;
    while (index < text.length) {
      final char = text[index];
      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) return index + 1;
      }
      index++;
    }
    return text.length;
  }

  /// A whole ``\command`` plus any immediately following brace groups.
  static (String, int) _command(String text, int start) {
    var index = start + 1;
    if (index < text.length && _isLetter(text[index])) {
      while (index < text.length && _isLetter(text[index])) {
        index++;
      }
    } else if (index < text.length) {
      index++; // Escaped character such as \% or \{.
    }
    var token = text.substring(start, index);
    while (index < text.length && text[index] == '{') {
      final end = _groupEnd(text, index);
      token += text.substring(index, end);
      index = end;
    }
    return (token, index);
  }

  static List<String> tokens(String latex) {
    final result = <String>[];
    var index = 0;
    while (index < latex.length) {
      final char = latex[index];
      if (char == r'\') {
        final (token, next) = _command(latex, index);
        result.add(token);
        index = next;
      } else if (char == '^' || char == '_') {
        var next = index + 1;
        if (next < latex.length && latex[next] == '{') {
          next = _groupEnd(latex, next);
        } else if (next < latex.length && latex[next] == r'\') {
          final (_, commandEnd) = _command(latex, next);
          next = commandEnd;
        } else if (next < latex.length) {
          next++;
        }
        result.add(latex.substring(index, next));
        index = next;
      } else if (char == '{') {
        final end = _groupEnd(latex, index);
        result.add(latex.substring(index, end));
        index = end;
      } else {
        result.add(char);
        index++;
      }
    }
    return result;
  }

  /// Every visible prefix, from the first token to the whole expression.
  static List<String> sequence(String latex) {
    final parts = tokens(latex);
    final prefixes = <String>[];
    for (var i = 0; i < parts.length; i++) {
      prefixes.add(parts.take(i + 1).join());
    }
    return prefixes;
  }

  /// The delay before writing [token], shaped to feel like a person at a board:
  /// digits flow quickly, operators and equals signs pause, commands settle.
  static Duration delayFor(String token, int index, List<String> tokens, double speed) {
    final effective = speed <= 0 ? 1.0 : speed;
    double millis;
    if (token.trim().isEmpty) {
      millis = 12;
    } else if (_operators.contains(token)) {
      millis = 170;
    } else if (token.startsWith(r'\')) {
      millis = 70;
    } else if (token.length == 1 && _isDigit(token)) {
      final previous = index > 0 ? tokens[index - 1] : '';
      millis = previous.length == 1 && _isDigit(previous) ? 22 : 44;
    } else {
      millis = 46;
    }
    return Duration(microseconds: (millis * 1000 / effective).round());
  }

  static bool _isDigit(String token) {
    final code = token.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }
}

/// Typesets [latex] and reveals it one token at a time.
///
/// The animation only advances while [playing] is true, so pausing the tutor
/// freezes the expression exactly where it was and resuming continues from the
/// same character rather than restarting the step.
class MathTypewriter extends StatefulWidget {
  const MathTypewriter({
    super.key,
    required this.latex,
    required this.playing,
    this.speed = 1.0,
    this.complete = false,
    this.fontSize = 18,
    this.color,
    this.onCompleted,
  });

  final String latex;

  /// Whether the reveal timer should be running.
  final bool playing;

  /// Playback speed multiplier; higher writes faster.
  final double speed;

  /// Show the whole expression immediately (used for finished steps).
  final bool complete;

  final double fontSize;
  final Color? color;

  /// Called once the final token has been written.
  final VoidCallback? onCompleted;

  @override
  State<MathTypewriter> createState() => _MathTypewriterState();
}

class _MathTypewriterState extends State<MathTypewriter> {
  late List<String> _tokens;
  int _count = 0;
  Timer? _timer;

  bool get _done => _count >= _tokens.length;

  @override
  void initState() {
    super.initState();
    _tokens = LatexReveal.tokens(widget.latex);
    if (widget.complete) _count = _tokens.length;
    _schedule();
  }

  @override
  void didUpdateWidget(covariant MathTypewriter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latex != widget.latex) {
      _timer?.cancel();
      _tokens = LatexReveal.tokens(widget.latex);
      _count = widget.complete ? _tokens.length : 0;
    }
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!widget.playing || widget.complete || _done) return;
    _timer = Timer(
      LatexReveal.delayFor(_tokens[_count], _count, _tokens, widget.speed),
      () {
        if (!mounted) return;
        setState(() => _count++);
        if (_done) {
          widget.onCompleted?.call();
        } else {
          _schedule();
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _tokens.take(_count).join();
    if (visible.isEmpty) {
      return SizedBox(
        height: widget.fontSize * 1.6,
        child: Align(
          alignment: Alignment.centerLeft,
          child: _Caret(color: widget.color),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Flexible(
          child: MathTex(visible, fontSize: widget.fontSize, color: widget.color),
        ),
        if (!_done) Padding(padding: const EdgeInsets.only(left: 2, bottom: 4), child: _Caret(color: widget.color)),
      ],
    );
  }
}

class _Caret extends StatelessWidget {
  const _Caret({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: 2,
        height: 18,
        color: color ?? Theme.of(context).colorScheme.primary,
      );
}
