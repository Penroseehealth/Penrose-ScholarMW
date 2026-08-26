import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';
import '../services/connectivity_manager.dart';
import 'offline_notices.dart';

/// Displays pending questions that were queued while offline.
/// Shows a collapsible panel above the chat input when there are queued items.
class PendingRequestQueue extends StatefulWidget {
  final ConnectivityManager connectivity;
  final void Function(Map<String, dynamic> question)? onRetry;
  final VoidCallback? onClearAll;

  const PendingRequestQueue({
    super.key,
    required this.connectivity,
    this.onRetry,
    this.onClearAll,
  });

  @override
  State<PendingRequestQueue> createState() => _PendingRequestQueueState();
}

class _PendingRequestQueueState extends State<PendingRequestQueue> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.connectivity,
        builder: (context, _) {
          if (!widget.connectivity.hasPendingQuestions) {
            return const SizedBox.shrink();
          }

          final count = widget.connectivity.pendingQuestions.length;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$count question${count == 1 ? '' : 's'} queued for sending',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (widget.connectivity.isOnline)
                          TextButton(
                            onPressed: _sendAll,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                            ),
                            child: const Text('Send All', style: TextStyle(fontSize: 12)),
                          ),
                        Icon(
                          _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 18,
                          color: context.colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_expanded) ...[
                  const Divider(height: 1, color: AppColors.border),
                  ...widget.connectivity.pendingQuestions.asMap().entries.map(
                        (entry) => _buildItem(entry.key, entry.value),
                      ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          OfflineNotices.random(),
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: context.colors.textMuted,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: widget.onClearAll ?? () => widget.connectivity.clearPendingQuestions(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Clear All', style: TextStyle(fontSize: 11, color: AppColors.error)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );

  Widget _buildItem(int index, Map<String, dynamic> question) {
    final message = question['message'] as String? ?? '';
    final timestamp = question['timestamp'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.length > 80 ? '${message.substring(0, 80)}...' : message,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (timestamp.isNotEmpty)
                  Text(
                    _formatTime(timestamp),
                    style: TextStyle(fontSize: 10, color: context.colors.textMuted),
                  ),
              ],
            ),
          ),
          if (widget.connectivity.isOnline && widget.onRetry != null)
            IconButton(
              icon: const Icon(Icons.send_rounded, size: 14),
              color: AppColors.primary,
              onPressed: () => widget.onRetry!(question),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
        ],
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  void _sendAll() {
    for (final q in List<Map<String, dynamic>>.from(widget.connectivity.pendingQuestions)) {
      widget.onRetry?.call(q);
    }
    widget.connectivity.clearPendingQuestions();
  }
}
