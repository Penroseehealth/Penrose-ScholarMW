import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/theme_colors.dart';
import '../../services/stem_service.dart';

class ProctorOverlay extends StatefulWidget {
  final String examType;
  final int examId;
  final bool active;
  final Widget child;
  final GlobalKey<ProctorOverlayState>? overlayKey;

  const ProctorOverlay({
    super.key,
    required this.examType,
    required this.examId,
    required this.active,
    required this.child,
    this.overlayKey,
  });

  @override
  State<ProctorOverlay> createState() => ProctorOverlayState();
}

class ProctorOverlayState extends State<ProctorOverlay> with WidgetsBindingObserver {
  final StemService _stemService = StemService();
  final FocusNode _focusNode = FocusNode();

  int _focusLostCount = 0;
  bool _showWarning = false;
  String _warningMessage = '';
  Timer? _warningTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _warningTimer?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.active) return;
    if (!_focusNode.hasFocus) {
      _focusLostCount++;
      _logEvent('focus_lost', eventData: {'focus_lost_count': _focusLostCount});
      _flashWarning('Focus lost — proctor event logged');
    } else {
      _logEvent('focus_gained', eventData: {'focus_lost_count': _focusLostCount});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.active) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _logEvent('app_background');
        _flashWarning('App went to background');
        break;
      case AppLifecycleState.resumed:
        _logEvent('app_resumed');
        break;
      default:
        break;
    }
  }

  Future<void> _logEvent(String eventType, {Map<String, dynamic>? eventData}) async {
    if (!widget.active) return;
    try {
      await _stemService.logProctorEvent(
        widget.examType,
        widget.examId,
        eventType,
        eventData: eventData,
      );
    } catch (_) {}
  }

  void reportEvent(String eventType, {Map<String, dynamic>? eventData}) {
    if (!widget.active) return;
    _logEvent(eventType, eventData: eventData);
    _flashWarning('${eventType.replaceAll('_', ' ').toUpperCase()} detected');
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.active) return KeyEventResult.ignored;
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
      if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyC) {
        reportEvent('copy_attempt', eventData: {'key': 'ctrl+c'});
        return KeyEventResult.handled;
      }
      if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyV) {
        reportEvent('paste_attempt', eventData: {'key': 'ctrl+v'});
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _flashWarning(String message) {
    if (!mounted) return;
    setState(() {
      _showWarning = true;
      _warningMessage = message;
    });
    _warningTimer?.cancel();
    _warningTimer = Timer(const Duration(seconds: 3), () {
      if (mounted)
        setState(() {
          _showWarning = false;
        });
    });
  }

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            widget.child,
            if (_showWarning)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showWarning ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [context.colors.warning, const Color(0xFFE8A317)],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: Colors.black87, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _warningMessage,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            'Events: $_focusLostCount',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.active && !_showWarning)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.colors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_outlined, color: context.colors.success, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Proctored',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.colors.success),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}
