import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import 'stem_symbol_palette.dart';
import 'stem_text.dart';

class EquationEditor extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool showPreview;
  final int maxLines;

  const EquationEditor({
    super.key,
    required this.controller,
    this.hintText = 'Type equation or use templates below...',
    this.showPreview = true,
    this.maxLines = 4,
  });

  @override
  State<EquationEditor> createState() => _EquationEditorState();
}

class _EquationEditorState extends State<EquationEditor> {
  bool _showPalette = false;
  bool _showTemplates = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _insertTemplate(String template) {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    final before = text.substring(0, sel.start);
    final after = text.substring(sel.end);
    final newText = '$before$template$after';
    widget.controller.text = newText;
    final cursorPos = before.length + template.indexOf('{}');
    widget.controller.selection = TextSelection.collapsed(
      offset: cursorPos >= 0 ? cursorPos : before.length + template.length,
    );
  }

  void _insertSymbol(String symbol) {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    final before = text.substring(0, sel.start);
    final after = text.substring(sel.end);
    widget.controller.text = '$before$symbol$after';
    widget.controller.selection = TextSelection.collapsed(
      offset: sel.start + symbol.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(),
          _buildEditor(),
          if (widget.showPreview && widget.controller.text.isNotEmpty)
            _buildPreview(),
          if (_showTemplates) _buildTemplateGrid(),
          if (_showPalette) _buildSymbolPalette(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _toolbarBtn(Icons.functions, 'Templates', () {
            setState(() {
              _showTemplates = !_showTemplates;
              if (_showTemplates) _showPalette = false;
            });
          }),
          _toolbarBtn(Icons.keyboard, 'Symbols', () {
            setState(() {
              _showPalette = !_showPalette;
              if (_showPalette) _showTemplates = false;
            });
          }),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.clear_all, size: 18),
            tooltip: 'Clear',
            onPressed: () => widget.controller.clear(),
            color: AppColors.textSecondary,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            icon: const Icon(Icons.content_copy, size: 18),
            tooltip: 'Copy LaTeX',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.controller.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('LaTeX copied'), duration: Duration(seconds: 1)),
              );
            },
            color: AppColors.textSecondary,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _toolbarBtn(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      color: AppColors.textSecondary,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: widget.controller,
        maxLines: widget.maxLines,
        minLines: 2,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          StemText(
            widget.controller.text,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateGrid() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'Quick Templates',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _templates.entries.map((entry) {
              return ActionChip(
                label: Text(
                  entry.key,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
                onPressed: () => _insertTemplate(entry.value),
                backgroundColor: AppColors.surfaceElevated,
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolPalette() {
    return StemSymbolPalette(
      onSymbolTap: _insertSymbol,
    );
  }

  static const _templates = {
    'a/b': '\\frac{a}{b}',
    '√': '\\sqrt{x}',
    '∛': '\\sqrt[3]{x}',
    'x²': 'x^{2}',
    'xⁿ': 'x^{n}',
    'x₁': 'x_{1}',
    '∑': '\\sum_{i=1}^{n}',
    '∫': '\\int_{a}^{b}',
    'lim': '\\lim_{x \\to \\infty}',
    '∞': '\\infty',
    '±': '\\pm',
    '×': '\\times',
    '÷': '\\div',
    '≠': '\\neq',
    '≤': '\\leq',
    '≥': '\\geq',
    '≈': '\\approx',
    '∈': '\\in',
    '⊂': '\\subset',
    '∪': '\\cup',
    '∩': '\\cap',
    'α': '\\alpha',
    'β': '\\beta',
    'γ': '\\gamma',
    'δ': '\\delta',
    'θ': '\\theta',
    'λ': '\\lambda',
    'π': '\\pi',
    'σ': '\\sigma',
    'φ': '\\phi',
    'ω': '\\omega',
    'Δ': '\\Delta',
    'Σ': '\\Sigma',
    'Ω': '\\Omega',
    'matrix': '\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}',
    'cases': '\\begin{cases} x & \\text{if } x>0 \\\\ -x & \\text{otherwise} \\end{cases}',
  };
}
