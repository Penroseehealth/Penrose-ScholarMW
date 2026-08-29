import 'dart:convert' show jsonDecode;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';

class AiBadge extends StatelessWidget {
  final String? label;
  const AiBadge({super.key, this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.colors.primaryGlow,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label ?? 'AI-generated',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
}

class AiDisclaimer extends StatelessWidget {
  const AiDisclaimer({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.warningMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: context.colors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Responses are AI-generated and may contain inaccuracies. Always verify with authoritative sources.',
                style: TextStyle(fontSize: 11, color: context.colors.textSecondary, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

class AiSourceChips extends StatelessWidget {
  final String? sourcesJson;
  const AiSourceChips({super.key, this.sourcesJson});

  List<String> _parse() {
    if (sourcesJson == null || sourcesJson!.isEmpty) return [];
    try {
      final parsed = jsonDecode(sourcesJson!);
      if (parsed is List) return parsed.map<String>((s) => s.toString()).toList();
    } catch (_) {}
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final sources = _parse();
    if (sources.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: sources
          .map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.source_rounded, size: 10, color: context.colors.textMuted),
                    const SizedBox(width: 3),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        s,
                        style: TextStyle(fontSize: 9, color: context.colors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class AiGovernanceBar extends StatelessWidget {
  final String? sourcesJson;
  final String? label;
  const AiGovernanceBar({super.key, this.sourcesJson, this.label});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) AiBadge(label: label),
          if (sourcesJson != null && sourcesJson!.isNotEmpty) ...[
            const SizedBox(height: 6),
            AiSourceChips(sourcesJson: sourcesJson),
          ],
        ],
      );
}
