import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';

class DataTableRenderer extends StatelessWidget {
  final List<String> headers;
  final List<Map<String, String>> rows;
  final String? title;

  DataTableRenderer({
    super.key,
    required this.headers,
    required this.rows,
    this.title,
  });

  factory DataTableRenderer.fromMarkdown(String markdown) {
    final lines = markdown.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) return DataTableRenderer(headers: [], rows: []);

    final headers = lines[0]
        .split('|')
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty && h != '---' && !RegExp(r'^[-:]+$').hasMatch(h))
        .toList();

    final rows = <Map<String, String>>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (RegExp(r'^\|[\s\-:|]+\|$').hasMatch(line)) continue;
      final cells = line
          .split('|')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      if (cells.length >= headers.length) {
        final row = <String, String>{};
        for (var j = 0; j < headers.length; j++) {
          row[headers[j]] = cells[j];
        }
        rows.add(row);
      }
    }
    return DataTableRenderer(headers: headers, rows: rows);
  }

  @override
  Widget build(BuildContext context) {
    if (headers.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                title!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(context.colors.surfaceElevated),
              dataRowColor: WidgetStateProperty.all(context.colors.surface),
              headingTextStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
              dataTextStyle: TextStyle(
                fontSize: 11,
                color: context.colors.textPrimary,
                height: 1.4,
              ),
              horizontalMargin: 12,
              columnSpacing: 16,
              columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
              rows: rows.map((row) {
                return DataRow(
                  cells: headers.map((h) => DataCell(Text(row[h] ?? ''))).toList(),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              '${rows.length} rows',
              style: TextStyle(fontSize: 10, color: context.colors.textMuted.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }
}

class SimpleBarChart extends StatelessWidget {
  final String title;
  final List<ChartBar> bars;

  SimpleBarChart({super.key, required this.title, required this.bars});

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();
    final maxVal = bars.map((b) => b.value).reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.colors.textSecondary,
            ),
          ),
          SizedBox(height: 12),
          ...bars.map((bar) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        bar.label,
                        style: TextStyle(fontSize: 10, color: context.colors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 18,
                            decoration: BoxDecoration(
                              color: context.colors.surfaceElevated,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: maxVal > 0 ? bar.value / maxVal : 0,
                            child: Container(
                              height: 18,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    bar.color ?? AppColors.primary,
                                    (bar.color ?? AppColors.primary).withValues(alpha: 0.6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: Text(
                        bar.value.toStringAsFixed(1),
                        style: TextStyle(fontSize: 10, color: context.colors.textPrimary),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  factory SimpleBarChart.fromMap(String title, Map<String, double> data) {
    final colors = [
      AppColors.primary,
      AppColors.teal,
      AppColors.info,
      AppColors.warning,
      AppColors.success,
      AppColors.error,
      AppColors.accent,
    ];
    return SimpleBarChart(
      title: title,
      bars: data.entries.toList().asMap().entries.map((entry) {
        return ChartBar(
          label: entry.value.key,
          value: entry.value.value,
          color: colors[entry.key % colors.length],
        );
      }).toList(),
    );
  }
}

class ChartBar {
  final String label;
  final double value;
  final Color? color;

  ChartBar({required this.label, required this.value, this.color});
}
