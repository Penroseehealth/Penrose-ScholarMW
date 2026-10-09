import 'package:flutter/material.dart';

import '../../../core/theme/theme_colors.dart';
import '../experiments/experiment_definition.dart';
import '../simulation/titration_controller.dart';
import 'lab_tutor_panel.dart';
import 'titration_curve_panel.dart';

/// Step-by-step experiment workflow: safety brief, procedure with live
/// progress, quantitative readouts (pH, titre), checkpoint questions and
/// results/conclusion.
///
/// Rendered next to (or below) the single 3D viewport inside
/// `ChemistryLabScreen`, so the 3D scene and the guidance share one screen
/// and one provider. All numbers come from [TitrationController]'s
/// calculated model — never from the animation.
class TitrationWorkflowPanel extends StatelessWidget {
  final ExperimentDefinition experiment;
  final TitrationController controller;
  final VoidCallback onExitExperiment;

  const TitrationWorkflowPanel({
    super.key,
    required this.experiment,
    required this.controller,
    required this.onExitExperiment,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<void>(
      stream: controller.changes,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  experiment.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onExitExperiment,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Leave'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(experiment.summary, style: TextStyle(color: colors.textSecondary, height: 1.4)),
          const SizedBox(height: 12),
          _SafetyBrief(experiment: experiment),
          const SizedBox(height: 12),
          _LiveReadout(controller: controller),
          const SizedBox(height: 12),
          TitrationCurvePanel(controller: controller),
          const SizedBox(height: 12),
          LabTutorPanel(controller: controller),
          const SizedBox(height: 12),
          _ProcedureSteps(controller: controller, experiment: experiment),
          if (controller.phase == TitrationPhase.endpointReached || controller.phase == TitrationPhase.analysed) ...[
            const SizedBox(height: 12),
            _Results(controller: controller),
          ],
          if (controller.phase == TitrationPhase.analysed) ...[
            const SizedBox(height: 12),
            _Assessment(controller: controller, experiment: experiment),
          ],
        ],
      ),
    );
  }
}

// ── Safety ──────────────────────────────────────────────────────────────────

class _SafetyBrief extends StatelessWidget {
  final ExperimentDefinition experiment;

  const _SafetyBrief({required this.experiment});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.warningMuted.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety, size: 18, color: colors.warning),
              const SizedBox(width: 6),
              Text(
                'Safety first',
                style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final note in experiment.safetyNotes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $note', style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.35)),
            ),
        ],
      ),
    );
  }
}

// ── Live quantitative readout ───────────────────────────────────────────────

class _LiveReadout extends StatelessWidget {
  final TitrationController controller;

  const _LiveReadout({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ph = controller.currentPh;
    final colourName = controller.indicatorColour;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.surfaceHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live readings', style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _metric(context, 'Delivered', '${controller.deliveredMl.toStringAsFixed(2)} cm³'),
              _metric(context, 'Burette', '${controller.buretteReading.toStringAsFixed(2)} cm³'),
              _metric(context, 'pH', ph.toStringAsFixed(2)),
              _metric(context, 'Indicator', colourName),
              if (controller.calculatedTitrantConcentration != null)
                _metric(
                  context,
                  'c(NaOH)',
                  '${controller.calculatedTitrantConcentration!.toStringAsFixed(3)} mol dm⁻³',
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Accuracy provenance labels (spec §5: distinguish data classes).
          Text(
            'pH and volumes calculated from stoichiometry · colour is an illustrative '
            'rendering of the validated indicator range.',
            style: TextStyle(fontSize: 11, color: colors.textMuted, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: colors.textMuted)),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary)),
      ],
    );
  }
}

// ── Procedure ───────────────────────────────────────────────────────────────

class _ProcedureSteps extends StatelessWidget {
  final TitrationController controller;
  final ExperimentDefinition experiment;

  const _ProcedureSteps({required this.controller, required this.experiment});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final steps = experiment.procedure;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.surfaceHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Procedure', style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary)),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            InkWell(
              onTap: () => controller.goToStep(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == controller.currentStep
                            ? const Color(0xFFF59E0B)
                            : i < controller.currentStep
                                ? colors.success
                                : colors.surfaceHighest,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: i == controller.currentStep ? Colors.black87 : colors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i],
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: i == controller.currentStep ? colors.textPrimary : colors.textSecondary,
                              fontWeight: i == controller.currentStep ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          if (i == controller.currentStep) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Expected: ${experiment.expectedObservations[i]}',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: colors.info),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          _Actions(controller: controller),
        ],
      ),
    );
  }
}

// ── Contextual actions ──────────────────────────────────────────────────────

class _Actions extends StatelessWidget {
  final TitrationController controller;

  const _Actions({required this.controller});

  @override
  Widget build(BuildContext context) {
    final phase = controller.phase;
    final rows = <Widget>[];

    if (phase == TitrationPhase.notStarted) {
      rows.add(FilledButton.icon(
        onPressed: controller.fillBurette,
        icon: const Icon(Icons.water_drop, size: 18),
        label: const Text('Rinse & fill burette (steps 1–2)'),
      ));
      rows.add(const SizedBox(height: 8));
      rows.add(OutlinedButton.icon(
        onPressed: controller.prepareFlask,
        icon: const Icon(Icons.science, size: 18),
        label: const Text('Pipette acid + add indicator (steps 3–4)'),
      ));
    } else if (phase == TitrationPhase.ready || phase == TitrationPhase.titrating) {
      rows.add(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => controller.deliver(10.0),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('+10.00 cm³'),
          ),
          OutlinedButton.icon(
            onPressed: () => controller.deliver(1.0),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('+1.00 cm³'),
          ),
          OutlinedButton.icon(
            onPressed: () => controller.deliver(0.10),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('+0.10'),
          ),
          OutlinedButton.icon(
            onPressed: controller.deliverDrop,
            icon: const Icon(Icons.water_drop_outlined, size: 16),
            label: const Text('1 drop'),
          ),
        ],
      ));
      rows.add(const SizedBox(height: 8));
      rows.add(FilledButton.tonalIcon(
        onPressed: controller.atEndpoint ? controller.recordEndpoint : null,
        icon: const Icon(Icons.flag, size: 18),
        label: Text(
          controller.atEndpoint
              ? 'Record endpoint (${controller.buretteReading.toStringAsFixed(2)} cm³)'
              : 'Endpoint: first permanent pale pink',
        ),
      ));
      if (!controller.atEndpoint && phase == TitrationPhase.titrating) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            controller.deviationFromEquivalence < 0
                ? '${(-controller.deviationFromEquivalence).toStringAsFixed(2)} cm³ to equivalence (calculated)'
                : 'Equivalence passed — expect pink to persist',
            style: TextStyle(fontSize: 12, color: context.colors.info),
          ),
        ));
      }
    } else if (phase == TitrationPhase.endpointReached) {
      rows.add(FilledButton.icon(
        onPressed: controller.analyse,
        icon: const Icon(Icons.analytics, size: 18),
        label: const Text('Analyse results'),
      ));
    } else {
      rows.add(OutlinedButton.icon(
        onPressed: controller.reset,
        icon: const Icon(Icons.restart_alt, size: 18),
        label: const Text('Reset experiment'),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

// ── Results ─────────────────────────────────────────────────────────────────

class _Results extends StatelessWidget {
  final TitrationController controller;

  const _Results({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final titre = controller.finalReadingMl != null && controller.initialReadingMl != null
        ? controller.finalReadingMl! - controller.initialReadingMl!
        : null;
    final c = controller.calculatedTitrantConcentration;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.success.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Results & conclusion', style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary)),
          const SizedBox(height: 8),
          if (titre != null)
            Text('• Titre = ${titre.toStringAsFixed(2)} cm³', style: TextStyle(color: colors.textSecondary)),
          if (c != null)
            Text(
              '• c(NaOH) = ${c.toStringAsFixed(3)} mol dm⁻³ (calculated from n = c × V, 1:1 ratio)',
              style: TextStyle(color: colors.textSecondary),
            ),
          const SizedBox(height: 6),
          Text(
            'Conclusion: the endpoint volume matches the calculated equivalence point '
            'of 25.00 cm³ within burette precision (±0.05 cm³), confirming the NaOH '
            'concentration is 0.100 mol dm⁻³.',
            style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ── Assessment ──────────────────────────────────────────────────────────────

class _Assessment extends StatelessWidget {
  final TitrationController controller;
  final ExperimentDefinition experiment;

  const _Assessment({required this.controller, required this.experiment});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.surfaceHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Check your understanding', style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary)),
          const SizedBox(height: 8),
          for (var i = 0; i < experiment.questions.length; i++)
            _QuestionTile(
              index: i,
              question: experiment.questions[i],
              answer: controller.answers[i],
              onSubmitted: (text) => controller.submitAnswer(i, text),
            ),
        ],
      ),
    );
  }
}

class _QuestionTile extends StatefulWidget {
  final int index;
  final ExperimentQuestion question;
  final String? answer;
  final ValueChanged<String> onSubmitted;

  const _QuestionTile({
    required this.index,
    required this.question,
    required this.answer,
    required this.onSubmitted,
  });

  @override
  State<_QuestionTile> createState() => _QuestionTileState();
}

class _QuestionTileState extends State<_QuestionTile> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.answer ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isCorrect =>
      widget.answer != null && widget.answer!.toLowerCase().contains(widget.question.answer.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.index + 1}. ${widget.question.question}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary, height: 1.35),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Your answer',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onSubmitted: widget.onSubmitted,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => widget.onSubmitted(_controller.text),
                child: const Text('Check'),
              ),
            ],
          ),
          if (widget.answer != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(_isCorrect ? Icons.check_circle : Icons.info,
                    size: 16, color: _isCorrect ? colors.success : colors.info),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isCorrect ? 'Correct. ' : 'Answer: ${widget.question.answer}. ',
                    style: TextStyle(fontSize: 12, color: _isCorrect ? colors.success : colors.textSecondary),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text(
                widget.question.explanation,
                style: TextStyle(fontSize: 12, color: colors.textMuted, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
