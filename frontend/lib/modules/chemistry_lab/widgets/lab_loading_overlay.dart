import 'package:flutter/material.dart';

import '../../../core/theme/theme_colors.dart';
import '../state/chemistry_lab_provider.dart';

/// Loading overlay shown while the 3D engine initialises.
///
/// Rendered above the viewport (or instead of content) during
/// [LabPhase.initialising] and while a scene reports progress.
class LabLoadingOverlay extends StatelessWidget {
  final ChemistryLabProvider provider;

  const LabLoadingOverlay({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.background.withValues(alpha: 0.85),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            provider.progressMessage ?? 'Starting the 3D laboratory…',
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 220,
            child: LinearProgressIndicator(
              value: provider.progress > 0 ? provider.progress : null,
            ),
          ),
        ],
      ),
    );
  }
}
