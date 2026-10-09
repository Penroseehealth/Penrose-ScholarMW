import 'package:flutter/material.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../services/chemistry_tutor_api.dart';
import '../simulation/titration_controller.dart';

/// AI tutor panel for the chemistry lab.
///
/// The tutor is grounded: every message is sent together with a snapshot of
/// the **validated** titration state from [TitrationController]'s calculated
/// model. The backend may explain, hint and question — it can never change
/// a number the engine produced, and when the network is unavailable the
/// panel says so honestly.
class LabTutorPanel extends StatefulWidget {
  final TitrationController controller;

  const LabTutorPanel({super.key, required this.controller});

  @override
  State<LabTutorPanel> createState() => _LabTutorPanelState();
}

class _LabTutorPanelState extends State<LabTutorPanel> {
  final ChemistryTutorApi _api = ChemistryTutorApi();
  final TextEditingController _question = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Turn> _turns = [];
  bool _sending = false;

  static const List<String> _suggestions = <String>[
    'Why did the indicator turn pink?',
    'How do I calculate the titre?',
    'What is the equivalence point?',
    'Why must I swirl the flask?',
    'What are the safety rules?',
  ];

  @override
  void dispose() {
    _question.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Validated snapshot — the single source of truth the backend may see.
  Map<String, dynamic> _stateSnapshot() {
    final c = widget.controller;
    final initial = c.initialReadingMl;
    final finalReading = c.finalReadingMl;
    final titre = (initial != null && finalReading != null) ? finalReading - initial : null;
    return <String, dynamic>{
      'experiment': 'acid_base_titration',
      'phase': c.phase.name,
      'step': c.currentStep,
      'delivered_ml': c.deliveredMl,
      'initial_reading_ml': initial,
      'final_reading_ml': finalReading,
      'titre_ml': titre,
      'current_ph': c.currentPh,
      'indicator_colour': c.indicatorColour,
      'at_endpoint': c.atEndpoint,
      'calculated_concentration': c.calculatedTitrantConcentration,
      'analyte': 'HCl',
      'titrant': 'NaOH',
      'analyte_concentration': 0.100,
      'expected_titre_ml': 25.0,
    };
  }

  Future<void> _ask(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || _sending) return;
    _question.clear();
    setState(() {
      _turns.add(_Turn.user(trimmed));
      _sending = true;
    });
    _jumpToBottom();

    final history = <Map<String, String>>[
      for (final turn in _turns.take(_turns.length - 1))
        {'role': turn.isUser ? 'user' : 'assistant', 'content': turn.text},
    ];

    final reply = await _api.explain(
      question: trimmed,
      state: _stateSnapshot(),
      history: history,
    );

    if (!mounted) return;
    setState(() {
      _sending = false;
      _turns.add(
        _Turn.tutor(
          reply?.text ??
              "I can't reach the tutor service right now. Your measured "
                  'values on screen are still valid — try again in a moment.',
          reply?.source ?? 'offline',
        ),
      );
    });
    _jumpToBottom();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 16, color: colors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Lab tutor',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 210,
          child: _turns.isEmpty
              ? Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    'Ask about the apparatus, the colour change or the '
                    'calculations. I answer using the verified state of '
                    'your run — not guesses.',
                    style: TextStyle(fontSize: 12.5, color: colors.textSecondary, height: 1.4),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  itemCount: _turns.length,
                  itemBuilder: (context, index) {
                    final turn = _turns[index];
                    return Align(
                      alignment: turn.isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: turn.isUser
                              ? colors.primary.withValues(alpha: 0.15)
                              : colors.textSecondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              turn.text,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (!turn.isUser && turn.source == 'deterministic')
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  'offline answer (verified data only)',
                                  style: TextStyle(fontSize: 9.5, color: colors.textSecondary),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) => ActionChip(
              label: Text(_suggestions[index], style: const TextStyle(fontSize: 11)),
              onPressed: _sending ? null : () => _ask(_suggestions[index]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _question,
                enabled: !_sending,
                textInputAction: TextInputAction.send,
                onSubmitted: _ask,
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ask the lab tutor…',
                  hintStyle: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_sending)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                onPressed: () => _ask(_question.text),
                icon: const Icon(Icons.send, size: 18),
                tooltip: 'Send question',
              ),
          ],
        ),
      ],
    );
  }
}

class _Turn {
  const _Turn.user(this.text)
      : isUser = true,
        source = '';

  const _Turn.tutor(this.text, this.source) : isUser = false;

  final String text;
  final bool isUser;

  /// 'ai', 'deterministic' or 'offline' — shown so the student knows the
  /// provenance of every answer.
  final String source;
}
