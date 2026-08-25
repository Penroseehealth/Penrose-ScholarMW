import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class AccessibleWrapper extends StatelessWidget {
  final Widget child;
  final String? semanticLabel;
  final String? semanticHint;
  final bool excludeSemantics;
  final bool autofocus;

  const AccessibleWrapper({
    super.key,
    required this.child,
    this.semanticLabel,
    this.semanticHint,
    this.excludeSemantics = false,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      explicitChildNodes: true,
      excludeSemantics: excludeSemantics,
      child: Focus(
        autofocus: autofocus,
        child: child,
      ),
    );
  }
}

class AccessibleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String semanticLabel;

  const AccessibleButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onPressed != null,
      child: GestureDetector(
        onTap: onPressed,
        child: child,
      ),
    );
  }
}

class AccessibleCard extends StatelessWidget {
  final Widget child;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool isSelected;

  const AccessibleCard({
    super.key,
    required this.child,
    required this.semanticLabel,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class KeyboardNavWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onSelect;

  const KeyboardNavWrapper({
    super.key,
    required this.child,
    this.onLeft,
    this.onRight,
    this.onUp,
    this.onDown,
    this.onSelect,
  });

  @override
  State<KeyboardNavWrapper> createState() => _KeyboardNavWrapperState();
}

class _KeyboardNavWrapperState extends State<KeyboardNavWrapper> {
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          switch (event.logicalKey) {
            case LogicalKeyboardKey.arrowLeft:
              widget.onLeft?.call();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.arrowRight:
              widget.onRight?.call();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.arrowUp:
              widget.onUp?.call();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.arrowDown:
              widget.onDown?.call();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.enter:
            case LogicalKeyboardKey.space:
              widget.onSelect?.call();
              return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}

class HighContrastBadge extends StatelessWidget {
  final Widget child;

  const HighContrastBadge({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'High contrast mode indicator',
      child: child,
    );
  }
}
