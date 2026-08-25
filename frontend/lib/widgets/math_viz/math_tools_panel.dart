import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MathToolsPanel extends StatelessWidget {
  final Function(String type, Map<String, dynamic> params) onToolSelected;

  const MathToolsPanel({super.key, required this.onToolSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: [
          _ToolButton(
            icon: Icons.show_chart,
            label: 'Graph',
            onTap: () => _showGraphDialog(context),
          ),
          _ToolButton(
            icon: Icons.pie_chart,
            label: 'Pie Chart',
            onTap: () => _showChartDialog(context, 'pie'),
          ),
          _ToolButton(
            icon: Icons.bar_chart,
            label: 'Bar Chart',
            onTap: () => _showChartDialog(context, 'bar'),
          ),
          _ToolButton(
            icon: Icons.equalizer,
            label: 'Histogram',
            onTap: () => _showHistogramDialog(context),
          ),
          _ToolButton(
            icon: Icons.timeline,
            label: 'Line Graph',
            onTap: () => _showLineGraphDialog(context),
          ),
          _ToolButton(
            icon: Icons.change_history,
            label: 'Triangle',
            onTap: () => onToolSelected('shape', {'shape': 'triangle'}),
          ),
          _ToolButton(
            icon: Icons.circle,
            label: 'Circle',
            onTap: () => onToolSelected('shape', {'shape': 'circle'}),
          ),
          _ToolButton(
            icon: Icons.crop_square,
            label: 'Quadrilateral',
            onTap: () => onToolSelected('shape', {'shape': 'quadrilateral'}),
          ),
          _ToolButton(
            icon: Icons.calculate,
            label: 'Equation',
            onTap: () => _showEquationDialog(context),
          ),
        ],
      ),
    );
  }

  void _showGraphDialog(BuildContext context) {
    final ctrl = TextEditingController(text: 'x^2');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Graph a Function', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'y = ',
                labelStyle: TextStyle(color: Colors.white54),
                hintText: 'e.g. x^2, sin(x), 2x+1',
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onToolSelected('graph', {'expression': ctrl.text});
            },
            child: const Text('Plot', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  void _showChartDialog(BuildContext context, String chartType) {
    final labelCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final labels = <String>[];
    final values = <double>[];

    void addEntry() {
      final label = labelCtrl.text.trim();
      final value = double.tryParse(valueCtrl.text.trim());
      if (label.isNotEmpty && value != null) {
        labels.add(label);
        values.add(value);
        labelCtrl.clear();
        valueCtrl.clear();
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: Text('${chartType == 'pie' ? 'Pie' : 'Bar'} Chart', style: const TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Title (optional)',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: labelCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Label',
                          labelStyle: TextStyle(color: Colors.white54),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: valueCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Value',
                          labelStyle: TextStyle(color: Colors.white54),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.cyanAccent),
                      onPressed: () => setState(addEntry),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: labels.isEmpty
                      ? const Center(child: Text('Add data points', style: TextStyle(color: Colors.white38)))
                      : ListView.builder(
                          itemCount: labels.length,
                          itemBuilder: (_, i) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${labels[i]}: ${values[i]}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                                onPressed: () => setState(() {
                                  labels.removeAt(i);
                                  values.removeAt(i);
                                }),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onToolSelected(chartType, {
                  'values': values,
                  'labels': labels,
                  'title': titleCtrl.text.isNotEmpty ? titleCtrl.text : null,
                });
              },
              child: const Text('Create', style: TextStyle(color: Colors.cyanAccent)),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistogramDialog(BuildContext context) {
    final dataCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Histogram', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dataCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Frequency values (comma-separated)',
                labelStyle: TextStyle(color: Colors.white54),
                hintText: 'e.g. 5, 12, 8, 3, 15',
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final values =
                  dataCtrl.text.split(',').map((s) => double.tryParse(s.trim())).whereType<double>().toList();
              Navigator.pop(ctx);
              if (values.isNotEmpty) {
                onToolSelected('histogram', {
                  'values': values,
                  'title': titleCtrl.text.isNotEmpty ? titleCtrl.text : null,
                });
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  void _showLineGraphDialog(BuildContext context) {
    final dataCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Line Graph', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dataCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Y-values (comma-separated)',
                labelStyle: TextStyle(color: Colors.white54),
                hintText: 'e.g. 2, 5, 8, 4, 9',
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final values =
                  dataCtrl.text.split(',').map((s) => double.tryParse(s.trim())).whereType<double>().toList();
              Navigator.pop(ctx);
              if (values.isNotEmpty) {
                onToolSelected('line', {
                  'values': values,
                  'title': titleCtrl.text.isNotEmpty ? titleCtrl.text : null,
                });
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  void _showEquationDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Insert Equation', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Use LaTeX syntax:\n\\frac{a}{b} \\quad \\sqrt{x} \\quad x^2 \\quad \\int \\quad \\sum',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: 'LaTeX expression',
                labelStyle: TextStyle(color: Colors.white54),
                hintText: 'e.g. \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}',
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onToolSelected('equation', {'latex': ctrl.text});
            },
            child: const Text('Insert', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
