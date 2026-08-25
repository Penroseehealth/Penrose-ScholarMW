import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ChartDataPoint {
  final double x;
  final double y;
  final String? label;

  const ChartDataPoint({required this.x, required this.y, this.label});
}

class StatisticalChartWidget extends StatelessWidget {
  final StatisticalChartType type;
  final List<ChartDataPoint> data;
  final String? title;
  final String? xLabel;
  final String? yLabel;
  final List<String>? categoryLabels;
  final double? width;
  final double? height;
  final Color barColor;
  final Color lineColor;
  final List<Color>? pieColors;

  const StatisticalChartWidget({
    super.key,
    required this.type,
    required this.data,
    this.title,
    this.xLabel,
    this.yLabel,
    this.categoryLabels,
    this.width,
    this.height,
    this.barColor = Colors.cyanAccent,
    this.lineColor = Colors.orangeAccent,
    this.pieColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                title!,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(child: _buildChart()),
        ],
      ),
    );
  }

  Widget _buildChart() {
    switch (type) {
      case StatisticalChartType.bar:
        return _buildBarChart();
      case StatisticalChartType.pie:
        return _buildPieChart();
      case StatisticalChartType.histogram:
        return _buildHistogram();
      case StatisticalChartType.line:
        return _buildLineChart();
      case StatisticalChartType.frequencyPolygon:
        return _buildFrequencyPolygon();
      case StatisticalChartType.cumulativeFrequency:
        return _buildCumulativeFrequency();
    }
  }

  Widget _buildBarChart() {
    final defaultColors = [
      Colors.cyanAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.greenAccent,
      Colors.pinkAccent,
      Colors.yellowAccent,
      Colors.lightBlueAccent,
      Colors.redAccent,
    ];
    final colors = pieColors ?? defaultColors;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: data.isEmpty ? 10 : data.map((d) => d.y).reduce((a, b) => a > b ? a : b) * 1.2,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && categoryLabels != null && idx < categoryLabels!.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(categoryLabels![idx], style: const TextStyle(color: Colors.white60, fontSize: 10)),
                  );
                }
                return Text(idx.toString(), style: const TextStyle(color: Colors.white60, fontSize: 10));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.y,
                color: colors[entry.key % colors.length],
                width: min(40, (300 / data.length)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPieChart() {
    final defaultColors = [
      Colors.cyanAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.greenAccent,
      Colors.pinkAccent,
      Colors.yellowAccent,
      Colors.lightBlueAccent,
      Colors.redAccent,
    ];
    final colors = pieColors ?? defaultColors;
    final total = data.isEmpty ? 1.0 : data.map((d) => d.y).reduce((a, b) => a + b);

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: data.asMap().entries.map((entry) {
                final pct = total > 0 ? (entry.value.y / total * 100) : 0;
                return PieChartSectionData(
                  value: entry.value.y,
                  color: colors[entry.key % colors.length],
                  title: '${pct.toStringAsFixed(1)}%',
                  radius: 50,
                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.asMap().entries.map((entry) {
            final label = categoryLabels != null && entry.key < categoryLabels!.length
                ? categoryLabels![entry.key]
                : 'Item ${entry.key + 1}';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, color: colors[entry.key % colors.length]),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHistogram() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.center,
        maxY: data.isEmpty ? 10 : data.map((d) => d.y).reduce((a, b) => a > b ? a : b) * 1.2,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && categoryLabels != null && idx < categoryLabels!.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(categoryLabels![idx], style: const TextStyle(color: Colors.white60, fontSize: 10)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.y,
                color: barColor.withAlpha(180),
                width: min(60, (360 / data.length)),
                borderRadius: BorderRadius.zero,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && categoryLabels != null && idx < categoryLabels!.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(categoryLabels![idx], style: const TextStyle(color: Colors.white60, fontSize: 10)),
                  );
                }
                return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white60, fontSize: 10));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.value.x, e.value.y)).toList(),
            isCurved: true,
            color: lineColor,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withAlpha(30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyPolygon() {
    final points = data.asMap().entries.map((e) => FlSpot(e.value.x, e.value.y)).toList();
    if (points.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: Colors.white38)));
    }
    final minX = points.first.x;
    final maxX = points.last.x;
    final interval = points.length > 1 ? points[1].x - points.first.x : 1;
    final extendedPoints = [
      FlSpot(minX - interval, 0),
      ...points,
      FlSpot(maxX + interval, 0),
    ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && categoryLabels != null && idx < categoryLabels!.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(categoryLabels![idx], style: const TextStyle(color: Colors.white60, fontSize: 10)),
                  );
                }
                return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white60, fontSize: 10));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: extendedPoints,
            isCurved: false,
            color: barColor,
            barWidth: 2,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildCumulativeFrequency() {
    final sorted = List<ChartDataPoint>.from(data)..sort((a, b) => a.x.compareTo(b.x));
    final n = sorted.length;
    if (n == 0) {
      return const Center(child: Text('No data', style: TextStyle(color: Colors.white38)));
    }

    List<FlSpot> spots = [];
    for (int i = 0; i < n; i++) {
      final cf = ((i + 1) / n * 100);
      spots.add(FlSpot(sorted[i].x, cf));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}%',
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 105,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

enum StatisticalChartType { bar, pie, histogram, line, frequencyPolygon, cumulativeFrequency }
