import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/smart_board_controller.dart';
import '../widgets/ask_panel.dart';
import '../widgets/board_canvas.dart';
import '../widgets/board_toolbar.dart';
import '../widgets/magnesium_lesson.dart';

/// Chemistry AI Tutor smart board: a live, writable classroom display that
/// belongs to the existing chemistry dashboard rather than a separate app.
class SmartBoardScreen extends StatefulWidget {
  const SmartBoardScreen({super.key, this.initialTopic});

  /// Topic or concept the student came from, when the chemistry dashboard had
  /// one selected. It seeds the Ask panel's context; the board content itself
  /// still starts from the magnesium demonstration lesson.
  final String? initialTopic;

  @override
  State<SmartBoardScreen> createState() => _SmartBoardScreenState();
}

class _SmartBoardScreenState extends State<SmartBoardScreen> {
  final SmartBoardController _controller = SmartBoardController();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDFE6EE),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (BuildContext context, Widget? child) => LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool narrow = constraints.maxWidth < 900;
              final bool compact = constraints.maxWidth < 640;
              return Padding(
                padding: EdgeInsets.all(compact ? 0 : 14),
                child: _boardFrame(narrow: narrow, compact: compact, available: constraints.maxWidth),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _boardFrame({required bool narrow, required bool compact, required double available}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 0 : 16),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF2C323A), Color(0xFF15191E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: compact
            ? const <BoxShadow>[]
            : <BoxShadow>[
                BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 30, offset: const Offset(0, 14)),
              ],
      ),
      padding: EdgeInsets.all(compact ? 0 : 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 0 : 10),
        child: Column(
          children: <Widget>[
            _boardHeader(compact: compact, narrow: narrow),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (!narrow)
                    Container(
                      width: 50,
                      color: const Color(0xFFE9EEF4),
                      child: BoardToolbar(controller: _controller, axis: Axis.vertical, onRequestMath: _promptMath),
                    ),
                  Expanded(child: _surface()),
                  _panelArea(available: available),
                ],
              ),
            ),
            if (narrow)
              Container(
                color: const Color(0xFFE9EEF4),
                child: BoardToolbar(controller: _controller, compact: true, onRequestMath: _promptMath),
              ),
            BoardFooterControls(controller: _controller),
          ],
        ),
      ),
    );
  }

  Widget _surface() => Container(
        color: const Color(0xFFF8FBFE),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: BoardCanvas(
                controller: _controller,
                lesson: const MagnesiumLesson(),
                onRequestText: _promptText,
                onEditText: _promptEditText,
              ),
            ),
            // Restrained screen sheen — never intercepts a pointer.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0.10),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.03),
                      ],
                      stops: const <double>[0, 0.45, 1],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _panelArea({required double available}) {
    final double panelWidth = available < 900 ? (available * 0.82).clamp(240.0, 320.0) : 300;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: _controller.panelExpanded ? panelWidth : 44,
      child: AskPanel(
        controller: _controller,
        expanded: _controller.panelExpanded,
        onToggle: _controller.togglePanel,
        topic: widget.initialTopic,
      ),
    );
  }

  /// The nav action labels only fit on wide boards — below 900px the header
  /// row would otherwise overflow, so the labels collapse to icons.
  Widget _boardHeader({required bool compact, required bool narrow}) => Container(
        height: compact ? 46 : 44,
        color: const Color(0xFF1D232A),
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 12),
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Back to chemistry dashboard',
              onPressed: () => context.push('/stem-subject/chemistry?title=Chemistry'),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: Colors.white70),
              visualDensity: VisualDensity.compact,
            ),
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(color: Color(0xFF2E6F63), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Text('C', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(width: 8),
            const Text('Chemistry AI Tutor',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
            if (!compact) ...<Widget>[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 1,
                height: 16,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              const Text('Smart Board', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
            const Spacer(),
            if (_controller.isDirty)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Text('●', style: TextStyle(fontSize: 9, color: Color(0xFFE0A75E))),
              ),
            _navAction(narrow, Icons.home_outlined, 'Home', () => context.go('/student')),
            _navAction(narrow, Icons.menu_book_outlined, 'Lessons',
                () => context.push('/stem-subject/chemistry?title=Chemistry')),
            _navAction(narrow, Icons.forum_outlined, 'Q&A', _controller.togglePanel),
            _navAction(narrow, Icons.settings_outlined, 'Settings', _showSettings),
          ],
        ),
      );

  Widget _navAction(bool iconOnly, IconData icon, String label, VoidCallback onTap) => Tooltip(
        message: label,
        child: Semantics(
          label: label,
          button: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              child: Row(
                children: <Widget>[
                  Icon(icon, size: 15, color: Colors.white70),
                  if (!iconOnly) ...<Widget>[
                    const SizedBox(width: 5),
                    Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  static const List<String> _mathTemplates = <String>[
    'Mg + O₂ → 2MgO',
    '2H₂ + O₂ → 2H₂O',
    'Mg → Mg²⁺ + 2e⁻',
    'n = m / M',
    'c = n / V',
    'pV = nRT',
    '2, 8, 2',
  ];

  static const List<String> _mathSymbols = <String>[
    '→',
    '⇌',
    '²',
    '⁺',
    '⁻',
    '₂',
    '₃',
    '×',
    '·',
    'Δ',
    '°',
    '≤',
    '≥',
    '√',
  ];

  Future<void> _promptMath() async {
    final TextEditingController textController = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext dialogContext, StateSetter setDialogState) => AlertDialog(
          title: const Text('Insert math or chemistry notation'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: textController,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Mg + O₂ → 2MgO   or   n = m / M',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _mathSymbols
                      .map(
                        (String symbol) => ActionChip(
                          label: Text(symbol, style: const TextStyle(fontSize: 15)),
                          tooltip: 'Insert $symbol',
                          onPressed: () {
                            textController.text += symbol;
                            textController.selection = TextSelection.fromPosition(
                              TextPosition(offset: textController.text.length),
                            );
                            setDialogState(() {});
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                const Text('Templates', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _mathTemplates
                      .map(
                        (String template) => ActionChip(
                          label: Text(template, style: const TextStyle(fontSize: 13)),
                          tooltip: 'Insert template',
                          onPressed: () {
                            textController.text = template;
                            setDialogState(() {});
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(textController.text),
              child: const Text('Insert on board'),
            ),
          ],
        ),
      ),
    );
    textController.dispose();
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    _controller.addText(trimmed, const Offset(140, 660), width: 640, fontSize: 26);
  }

  /// Editing an existing text object — used by the text tool, a second click
  /// on a text object, and the toolbar's "Edit selected text" action.
  Future<void> _promptEditText(String textId) => showBoardTextEditor(context, _controller, textId);

  Future<void> _promptText(Offset boardPoint) async {
    final TextEditingController textController = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Add text to the board'),
        content: TextField(
          controller: textController,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Type the note or equation'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(textController.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    textController.dispose();
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    _controller.addText(trimmed, boardPoint, width: 520);
  }

  Future<void> _showSettings() => showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Board settings and shortcuts'),
          content: const SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Shortcuts', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text('Ctrl+Z / Ctrl+Shift+Z — undo and redo'),
                Text('Delete — remove the selected object'),
                Text('Esc — clear the selection'),
                Text('Space + drag, or middle mouse — pan the board'),
                Text('Ctrl + scroll — zoom the board'),
                SizedBox(height: 14),
                Text('Notes', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text('Ink, shapes, text and pages are kept on this device and '
                    'restored when you reopen the board.'),
                Text('AI answers come from the existing ScholarAI tutor endpoint. '
                    'Nothing is generated locally.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
          ],
        ),
      );
}
