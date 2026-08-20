import 'dart:convert' show jsonDecode;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/services.dart';

class DataAnalysisScreen extends StatefulWidget {
  const DataAnalysisScreen({super.key});

  @override
  State<DataAnalysisScreen> createState() => _DataAnalysisScreenState();
}

class _DataAnalysisScreenState extends State<DataAnalysisScreen> {
  final AiService _aiService = AiService();
  final TextEditingController _csvCtrl = TextEditingController();
  final TextEditingController _questionCtrl = TextEditingController();

  Map<String, dynamic>? _result;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSample();
  }

  void _loadSample() {
    _csvCtrl.text = '''student,subject,score,grade,attendance_pct
Chimwemwe Banda,Mathematics,78,B,85
Aisha Kamwendo,Mathematics,92,A+,95
Takondwa Moyo,Mathematics,65,C+,72
Fatsani Gondwe,Mathematics,88,A,90
Memory Phiri,Mathematics,71,B-,80
Endwell Chipeta,Mathematics,95,A+,98
Chikondi Msowoya,Mathematics,58,D,65
Tanaka Mwale,Mathematics,82,B+,87
Gladys Jere,Mathematics,76,B,83
Wesley Nkhoma,Mathematics,84,B+,89''';
  }

  Future<void> _analyze() async {
    final csv = _csvCtrl.text.trim();
    if (csv.isEmpty) {
      setState(() => _error = 'Please paste some CSV data');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    final res = await _aiService.analyzeData(
      csvText: csv,
      question: _questionCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['success']) {
          _result = res['data'];
        } else {
          _error = res['error'] ?? 'Analysis failed';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.insights_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text(
              'Data Analysis Workspace',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Load sample data',
            onPressed: _loadSample,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('Dataset (CSV format)'),
            const SizedBox(height: 6),
            _buildCsvInput(),
            const SizedBox(height: 16),
            _buildSectionLabel('Ask a question (optional)'),
            const SizedBox(height: 6),
            _buildQuestionInput(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _analyze,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.analytics_rounded, size: 18),
                label: Text(_isLoading ? 'Analyzing...' : 'Analyze Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _buildError(_error!),
            ],
            if (_result != null) ...[
              const SizedBox(height: 24),
              _buildResults(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildCsvInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _csvCtrl,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: AppColors.textPrimary,
        ),
        maxLines: 10,
        decoration: const InputDecoration(
          hintText: 'name,score,grade\nAlice,85,A\nBob,72,B',
          hintStyle: TextStyle(
            color: AppColors.textMuted,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildQuestionInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _questionCtrl,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        decoration: const InputDecoration(
          hintText: 'e.g. What is the average score? Which student performed best?',
          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final data = _result!;
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    final sampleData = data['sample_data'] as List<dynamic>? ?? [];
    final headers = data['headers'] as List<dynamic>? ?? [];
    final analysis = data['analysis'] as String? ?? '';
    final sources = data['sources'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGovernanceBadge(sources),
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionLabel('Column Statistics'),
          const SizedBox(height: 8),
          _buildStatsCards(stats),
        ],
        if (sampleData.isNotEmpty && headers.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionLabel('Sample Data'),
          const SizedBox(height: 8),
          _buildDataTable(headers.cast<String>(), sampleData),
        ],
        if (analysis.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionLabel('AI Analysis'),
          const SizedBox(height: 8),
          _buildAnalysisCard(analysis),
        ],
      ],
    );
  }

  Widget _buildGovernanceBadge(dynamic sources) {
    List<String> sourceList = [];
    if (sources is String && sources.isNotEmpty) {
      try {
        final parsed = jsonDecode(sources);
        if (parsed is List) {
          sourceList = parsed.map<String>((s) => s.toString()).toList();
        }
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'AI-generated analysis',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (sourceList.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: sourceList.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.source_rounded, size: 10, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        s,
                        style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> stats) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: stats.entries.map((e) {
        final s = e.value as Map<String, dynamic>;
        return Container(
          width: (MediaQuery.of(context).size.width - 48) / 2,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.key,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              _statRow('Mean', '${s['mean']}'),
              _statRow('Min', '${s['min']}'),
              _statRow('Max', '${s['max']}'),
              _statRow('Std Dev', '${s['std_dev']}'),
              _statRow('Count', '${s['count']}'),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<String> headers, List<dynamic> rows) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.surfaceElevated),
          dataRowColor: WidgetStateProperty.all(AppColors.surface),
          columns: headers
              .map((h) => DataColumn(
                    label: Text(
                      h,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ))
              .toList(),
          rows: rows.take(10).map((row) {
            final map = row as Map<String, dynamic>;
            return DataRow(
              cells: headers
                  .map((h) => DataCell(
                        Text(
                          '${map[h] ?? ''}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                        ),
                      ))
                  .toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(String analysis) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        analysis,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textPrimary,
          height: 1.6,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _csvCtrl.dispose();
    _questionCtrl.dispose();
    super.dispose();
  }
}
