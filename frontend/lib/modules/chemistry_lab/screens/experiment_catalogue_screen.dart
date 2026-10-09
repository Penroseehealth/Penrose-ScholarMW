import 'package:flutter/material.dart';

import '../../../core/theme/theme_colors.dart';
import '../experiments/experiment_catalogue.dart';
import '../experiments/experiment_definition.dart';

/// Experiment selection: cards from [ExperimentCatalogue] with objectives
/// and safety summary.
///
/// Pops with the selected experiment **id** (or null) — the parent screen
/// stays the single owner of the 3D viewport, so choosing an experiment
/// changes the parent's mode instead of stacking a second viewport.
class ExperimentCatalogueScreen extends StatelessWidget {
  const ExperimentCatalogueScreen({super.key});

  static Future<String?> open(BuildContext context) => Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const ExperimentCatalogueScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: const Text('Experiment Catalogue'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: ExperimentCatalogue.all.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _ExperimentCard(
          experiment: ExperimentCatalogue.all[i],
          onOpen: () => Navigator.of(context).pop(ExperimentCatalogue.all[i].id),
        ),
      ),
    );
  }
}

class _ExperimentCard extends StatelessWidget {
  final ExperimentDefinition experiment;
  final VoidCallback onOpen;

  const _ExperimentCard({required this.experiment, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.science_outlined, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      experiment.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                experiment.summary,
                style: TextStyle(color: colors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _tag(context, '${experiment.objectives.length} objectives', Icons.flag_outlined),
                  _tag(context, '${experiment.procedure.length} steps', Icons.format_list_numbered),
                  _tag(context, '${experiment.questions.length} checks', Icons.quiz_outlined),
                  _tag(context, 'Safety briefed', Icons.health_and_safety_outlined),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, String text, IconData icon) => Chip(
        visualDensity: VisualDensity.compact,
        avatar: Icon(icon, size: 14),
        label: Text(text, style: const TextStyle(fontSize: 12)),
      );
}
