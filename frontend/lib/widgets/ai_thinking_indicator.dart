import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';

enum ThinkingState {
  analyzing,
  solving,
  reading,
  transcribing,
  preparing,
  generating,
}

class AIThinkingIndicator extends StatefulWidget {
  final ThinkingState state;
  final String? customMessage;

  const AIThinkingIndicator({
    super.key,
    this.state = ThinkingState.analyzing,
    this.customMessage,
  });

  @override
  State<AIThinkingIndicator> createState() => _AIThinkingIndicatorState();
}

class _AIThinkingIndicatorState extends State<AIThinkingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _dot1;
  late Animation<double> _dot2;
  late Animation<double> _dot3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _dot1 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.3)),
    );
    _dot2 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.5)),
    );
    _dot3 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.7)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getMessage() {
    if (widget.customMessage != null) return widget.customMessage!;
    switch (widget.state) {
      case ThinkingState.analyzing:
        return 'Analyzing your question...';
      case ThinkingState.solving:
        return 'Solving the mathematics problem...';
      case ThinkingState.reading:
        return 'Reading your document...';
      case ThinkingState.transcribing:
        return 'Transcribing your voice...';
      case ThinkingState.preparing:
        return 'Preparing your explanation...';
      case ThinkingState.generating:
        return 'Generating content...';
    }
  }

  IconData _getIcon() {
    switch (widget.state) {
      case ThinkingState.analyzing:
        return Icons.psychology_rounded;
      case ThinkingState.solving:
        return Icons.functions_rounded;
      case ThinkingState.reading:
        return Icons.description_rounded;
      case ThinkingState.transcribing:
        return Icons.mic_rounded;
      case ThinkingState.preparing:
        return Icons.auto_awesome_rounded;
      case ThinkingState.generating:
        return Icons.code_rounded;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.3),
                    AppColors.primaryDark.withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getIcon(), size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getMessage(),
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (ctx, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDot(_dot1.value),
                        const SizedBox(width: 4),
                        _buildDot(_dot2.value),
                        const SizedBox(width: 4),
                        _buildDot(_dot3.value),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildDot(double value) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.3 + value * 0.7),
          borderRadius: BorderRadius.circular(3),
        ),
      );
}
