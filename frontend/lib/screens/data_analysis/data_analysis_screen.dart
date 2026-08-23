import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/services.dart';
import '../../widgets/ai_governance_widgets.dart';
import '../../widgets/stem_text.dart';
import '../../core/theme/theme_colors.dart';

class DataAnalysisScreen extends StatefulWidget {
  DataAnalysisScreen({super.key});

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
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        title: Row(
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
            icon: Icon(Icons.refresh_rounded, color: context.colors.textSecondary),
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
            SizedBox(height: 6),
            _buildCsvInput(),
            SizedBox(height: 16),
            _buildSectionLabel('Ask a question (optional)'),
            SizedBox(height: 6),
            _buildQuestionInput(),
            SizedBox(height: 16),
            Semantics(
              button: true,
              label: 'Analyze data',
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _analyze,
                  icon: _isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(Icons.analytics_rounded, size: 18),
                  label: Text(_isLoading ? 'Analyzing...' : 'Analyze Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: 12),
              _buildError(_error!),
            ],
            if (_result != null) ...[
              SizedBox(height: 24),
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
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.colors.textSecondary,
      ),
    );
  }

  Widget _buildCsvInput() {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: TextField(
        controller: _csvCtrl,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: context.colors.textPrimary,
        ),
        maxLines: 10,
        decoration: InputDecoration(
          hintText: 'name,score,grade\nAlice,85,A\nBob,72,B',
          hintStyle: TextStyle(
            color: context.colors.textMuted,
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
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: TextField(
        controller: _questionCtrl,
        style: TextStyle(fontSize: 13, color: context.colors.textPrimary),
        decoration: InputDecoration(
          hintText: 'e.g. What is the average score? Which student performed best?',
          hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 13),
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
        color: context.colors.errorMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: context.colors.error, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(msg, style: TextStyle(color: context.colors.error, fontSize: 13)),
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
        AiGovernanceBar(sourcesJson: sources is String ? sources : null, label: 'AI-generated analysis'),
        if (stats.isNotEmpty) ...[
          SizedBox(height: 16),
          _buildSectionLabel('Column Statistics'),
          SizedBox(height: 8),
          _buildStatsCards(stats),
        ],
        if (sampleData.isNotEmpty && headers.isNotEmpty) ...[
          SizedBox(height: 16),
          _buildSectionLabel('Sample Data'),
          SizedBox(height: 8),
          _buildDataTable(headers.cast<String>(), sampleData),
        ],
        if (analysis.isNotEmpty) ...[
          SizedBox(height: 16),
          _buildSectionLabel('AI Analysis'),
          SizedBox(height: 8),
          _buildAnalysisCard(analysis),
        ],
      ],
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
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.key,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 8),
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
          Text(label, style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
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
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(context.colors.surfaceElevated),
          dataRowColor: WidgetStateProperty.all(context.colors.surface),
          columns: headers
              .map((h) => DataColumn(
                    label: Text(
                      h,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textSecondary,
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
                          style: TextStyle(fontSize: 11, color: context.colors.textPrimary),
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
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: StemText(
        analysis,
        style: TextStyle(
          fontSize: 13,
          color: context.colors.textPrimary,
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
