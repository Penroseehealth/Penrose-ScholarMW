import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/connectivity_manager.dart';

/// Reusable offline banner that displays at the top of screens.
/// Listens to [ConnectivityManager] and shows/hides automatically.
class OfflineBanner extends StatelessWidget {
  final ConnectivityManager connectivity;
  final Widget child;

  const OfflineBanner({
    super.key,
    required this.connectivity,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: connectivity,
        builder: (context, _) {
          if (connectivity.isOnline) return child;

          return Column(
            children: [
              _buildBanner(context),
              Expanded(child: child),
            ],
          );
        },
      );

  Widget _buildBanner(BuildContext context) {
    final isReconnecting = connectivity.isConnecting;
    final bgColor = isReconnecting ? Colors.orange.shade900 : Colors.red.shade900;
    final icon = isReconnecting ? Icons.sync_rounded : Icons.wifi_off_rounded;
    final label = isReconnecting ? 'Reconnecting...' : 'Offline — AI features unavailable';

    return Material(
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (connectivity.hasPendingQuestions)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${connectivity.pendingQuestions.length} queued',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact inline offline indicator for use in app bars or input areas.
class OfflineIndicator extends StatelessWidget {
  final ConnectivityManager connectivity;

  const OfflineIndicator({super.key, required this.connectivity});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: connectivity,
        builder: (context, _) {
          if (connectivity.isOnline) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 14),
                const SizedBox(width: 6),
                Text(
                  connectivity.statusMessage,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
            ),
          );
        },
      );
}
