import 'package:flutter/material.dart';

import '../models/board_models.dart';
import '../state/smart_board_controller.dart';

/// Classroom-style tool strip. Renders vertically beside the board on wide
/// layouts and as a scrollable strip on narrow ones.
class BoardToolbar extends StatelessWidget {
  const BoardToolbar({
    super.key,
    required this.controller,
    this.axis = Axis.horizontal,
    this.compact = false,
    this.onRequestMath,
  });

  final SmartBoardController controller;
  final Axis axis;
  final bool compact;

  /// Opens the Math / Equation composer (owned by the hosting screen).
  final VoidCallback? onRequestMath;

  @override
  Widget build(BuildContext context) {
    final double buttonSize = compact ? 34 : 38;
    final List<Widget> items = <Widget>[
      _toolButton(context, BoardTool.select, Icons.near_me_outlined, 'Select and move', buttonSize),
      _toolButton(context, BoardTool.pen, Icons.edit_outlined, 'Pen', buttonSize),
      _toolButton(context, BoardTool.highlighter, Icons.brush_outlined, 'Highlighter', buttonSize),
      _toolButton(context, BoardTool.eraser, Icons.auto_fix_normal_outlined, 'Eraser', buttonSize),
      _toolButton(context, BoardTool.pointer, Icons.gps_fixed_rounded, 'Laser pointer', buttonSize),
      _shapeButton(context, buttonSize),
      _toolButton(context, BoardTool.text, Icons.title_rounded, 'Text', buttonSize),
      _iconButton(context, Icons.functions_rounded, 'Math / equation', buttonSize, onTap: onRequestMath),
      _iconButton(
        context,
        Icons.edit_note,
        'Edit selected text',
        buttonSize,
        enabled: _selectedTextId(controller) != null,
        onTap: () {
          final String? id = _selectedTextId(controller);
          if (id != null) showBoardTextEditor(context, controller, id);
        },
      ),
      _iconButton(
        context,
        Icons.backspace_outlined,
        'Erase selected object',
        buttonSize,
        enabled: controller.selectedId != null,
        onTap: controller.deleteSelected,
      ),
      _separator(context),
      ..._colorSwatches(context),
      _separator(context),
      _iconButton(context, Icons.tune_rounded, 'Ink, eraser and opacity', buttonSize,
          onTap: () => _showInkSettings(context)),
      _iconButton(
        context,
        Icons.undo_rounded,
        'Undo (Ctrl+Z)',
        buttonSize,
        enabled: controller.canUndo,
        onTap: controller.undo,
      ),
      _iconButton(
        context,
        Icons.redo_rounded,
        'Redo (Ctrl+Shift+Z)',
        buttonSize,
        enabled: controller.canRedo,
        onTap: controller.redo,
      ),
      PopupMenuButton<String>(
        tooltip: 'Clear board',
        enabled: true,
        onSelected: (String value) => _handleClear(context, value),
        itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
          PopupMenuItem<String>(value: 'ink', child: Text('Clear ink and shapes')),
          PopupMenuItem<String>(value: 'page', child: Text('Clear entire page')),
        ],
        child: _chrome(context, Icons.delete_outline_rounded, 'Clear', buttonSize, enabled: true, showTooltip: false),
      ),
    ];

    return axis == Axis.horizontal
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: items),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(children: items),
          );
  }

  Widget _separator(BuildContext context) => Padding(
        padding: axis == Axis.horizontal
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 8)
            : const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Container(
          width: axis == Axis.horizontal ? 1 : 20,
          height: axis == Axis.horizontal ? 20 : 1,
          color: const Color(0xFFD5DEE8),
        ),
      );

  List<Widget> _colorSwatches(BuildContext context) => kBoardInkColors.map((Color swatch) {
        final bool selected = controller.color.toARGB32() == swatch.toARGB32();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Semantics(
            label: 'Ink colour',
            selected: selected,
            button: true,
            child: GestureDetector(
              onTap: () => controller.setColor(swatch),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? const Color(0xFF12294A) : const Color(0xFFD5DEE8),
                    width: selected ? 2 : 1,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(growable: false);

  Widget _toolButton(BuildContext context, BoardTool tool, IconData icon, String tooltip, double size) {
    final bool selected = controller.tool == tool;
    return _chrome(context, icon, tooltip, size,
        selected: selected, enabled: true, onTap: () => controller.setTool(tool));
  }

  Widget _shapeButton(BuildContext context, double size) {
    final bool selected = controller.tool == BoardTool.shape;
    return PopupMenuButton<BoardShapeType>(
      tooltip: 'Shapes',
      onSelected: controller.setShapeType,
      itemBuilder: (BuildContext context) => const <PopupMenuEntry<BoardShapeType>>[
        PopupMenuItem<BoardShapeType>(value: BoardShapeType.line, child: Text('Line')),
        PopupMenuItem<BoardShapeType>(value: BoardShapeType.arrow, child: Text('Arrow')),
        PopupMenuItem<BoardShapeType>(value: BoardShapeType.rectangle, child: Text('Rectangle')),
        PopupMenuItem<BoardShapeType>(value: BoardShapeType.ellipse, child: Text('Circle / ellipse')),
        PopupMenuItem<BoardShapeType>(value: BoardShapeType.triangle, child: Text('Triangle')),
      ],
      child: _chrome(context, Icons.category_outlined, 'Shapes', size,
          selected: selected, enabled: true, showTooltip: false),
    );
  }

  Widget _iconButton(
    BuildContext context,
    IconData icon,
    String tooltip,
    double size, {
    VoidCallback? onTap,
    bool enabled = true,
  }) =>
      _chrome(context, icon, tooltip, size, enabled: enabled && onTap != null, onTap: onTap);

  /// The id of the selected text object, without the `t:` selection prefix.
  static String? _selectedTextId(SmartBoardController controller) {
    final String? id = controller.selectedId;
    if (id == null || !id.startsWith('t:')) return null;
    final String key = id.substring(2);
    for (final BoardTextObject text in controller.currentPage.texts) {
      if (text.id == key) return key;
    }
    return null;
  }

  Widget _chrome(
    BuildContext context,
    IconData icon,
    String tooltip,
    double size, {
    bool selected = false,
    bool enabled = true,
    bool showTooltip = true,
    VoidCallback? onTap,
  }) {
    final Color background = selected ? const Color(0xFF12294A) : Colors.transparent;
    final Color foreground = selected
        ? Colors.white
        : enabled
            ? const Color(0xFF2B3F58)
            : const Color(0xFF9AA9BA);
    // PopupMenuButton supplies its own tooltip; wrapping again would nest two
    // identical tooltips on the same button.
    final Widget content = showTooltip
        ? Tooltip(
            message: tooltip,
            child: Semantics(
              label: tooltip,
              button: true,
              selected: selected,
              enabled: enabled,
              child: _chromeBody(icon, size, background, foreground, onTap, enabled),
            ),
          )
        : Semantics(
            label: tooltip,
            button: true,
            selected: selected,
            enabled: enabled,
            child: _chromeBody(icon, size, background, foreground, onTap, enabled),
          );
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: content);
  }

  Widget _chromeBody(
    IconData icon,
    double size,
    Color background,
    Color foreground,
    VoidCallback? onTap,
    bool enabled,
  ) =>
      InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: size * 0.5, color: foreground),
        ),
      );

  Future<void> _showInkSettings(BuildContext context) => showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Ink and eraser'),
          content: SizedBox(
            width: 340,
            child: ListenableBuilder(
              listenable: controller,
              builder: (BuildContext context, Widget? child) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Stroke width — ${controller.strokeWidth.toStringAsFixed(1)} px'),
                  Slider(
                    value: controller.strokeWidth.clamp(1, 18),
                    min: 1,
                    max: 18,
                    onChanged: controller.setStrokeWidth,
                  ),
                  Text('Opacity — ${(controller.opacity * 100).round()}%'),
                  Slider(
                    value: controller.opacity.clamp(0.1, 1),
                    min: 0.1,
                    max: 1,
                    onChanged: controller.setOpacity,
                  ),
                  Text('Eraser size — ${controller.eraserRadius.round()} px'),
                  Slider(
                    value: controller.eraserRadius.clamp(6, 60),
                    min: 6,
                    max: 60,
                    onChanged: controller.setEraserRadius,
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );

  Future<void> _handleClear(BuildContext context, String value) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(value == 'ink' ? 'Clear all ink?' : 'Clear the entire page?'),
        content: Text(
          value == 'ink'
              ? 'Every pen, highlighter and shape stroke on this page will be removed. Text stays.'
              : 'Ink, shapes, text and the lesson on this page will be removed. This can be undone.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (value == 'ink') {
      controller.clearInk();
    } else {
      controller.clearPage();
    }
  }
}

/// Page navigation, zoom and save status.
class BoardFooterControls extends StatelessWidget {
  const BoardFooterControls({super.key, required this.controller});

  final SmartBoardController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFF2F5F9),
        border: Border(top: BorderSide(color: Color(0xFFDCE4ED))),
      ),
      child: Row(
        children: <Widget>[
          _small(context, Icons.chevron_left_rounded, 'Previous page',
              enabled: controller.pageIndex > 0, onTap: controller.previousPage),
          Text(
            '${controller.pageIndex + 1} / ${controller.pageCount}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2B3F58)),
          ),
          _small(context, Icons.chevron_right_rounded, 'Next page',
              enabled: controller.pageIndex < controller.pageCount - 1, onTap: controller.nextPage),
          const SizedBox(width: 4),
          _small(context, Icons.add_rounded, 'Add page', onTap: controller.addPage),
          _small(context, Icons.copy_all_rounded, 'Duplicate page', onTap: controller.duplicatePage),
          _small(context, Icons.delete_outline_rounded, 'Delete page', onTap: controller.deletePage),
          const Spacer(),
          _small(context, Icons.remove_rounded, 'Zoom out', onTap: controller.zoomOut),
          GestureDetector(
            onTap: controller.resetZoom,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${(controller.zoom * 100).round()}%',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2B3F58)),
              ),
            ),
          ),
          _small(context, Icons.add_rounded, 'Zoom in', onTap: controller.zoomIn),
          _small(context, Icons.fit_screen_outlined, 'Fit to board', onTap: controller.fitToBoard),
          const SizedBox(width: 6),
          Text(
            controller.isSaving ? 'Saving…' : (controller.isDirty ? 'Unsaved' : 'Saved'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: controller.isDirty ? const Color(0xFFB45309) : const Color(0xFF15803D),
            ),
          ),
          _small(context, Icons.save_outlined, 'Save board', onTap: controller.save),
        ],
      ),
    );
  }

  Widget _small(
    BuildContext context,
    IconData icon,
    String tooltip, {
    required VoidCallback onTap,
    bool enabled = true,
  }) =>
      Tooltip(
        message: tooltip,
        child: Semantics(
          label: tooltip,
          button: true,
          enabled: enabled,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(icon, size: 17, color: enabled ? const Color(0xFF2B3F58) : const Color(0xFF9AA9BA)),
            ),
          ),
        ),
      );
}

/// Opens the editor for an existing board text object (a note, a heading or an
/// AI answer written onto the board) and saves the change through the
/// controller, so the edit lands in the undo history.
Future<void> showBoardTextEditor(
  BuildContext context,
  SmartBoardController controller,
  String textId,
) async {
  BoardTextObject? target;
  for (final BoardTextObject text in controller.currentPage.texts) {
    if (text.id == textId) {
      target = text;
      break;
    }
  }
  if (target == null) return;

  final TextEditingController input = TextEditingController(text: target.text);
  final String? value = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('Edit text on the board'),
      content: SizedBox(
        width: 460,
        child: TextField(
          controller: input,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Type the note or equation',
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(input.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  input.dispose();

  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == target.text) return;
  controller.updateText(textId, trimmed);
}
