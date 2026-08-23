import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../core/theme/theme_colors.dart';

class AnalyticsExportScreen extends StatefulWidget {
  AnalyticsExportScreen({super.key});

  @override
  State<AnalyticsExportScreen> createState() => _AnalyticsExportScreenState();
}

class _AnalyticsExportScreenState extends State<AnalyticsExportScreen> {
  final ApiService _api = ApiService();

  Map<String, dynamic> _summary = {};
  List<dynamic> _recentActivity = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.get('/stem/export/summary');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _summary = data is Map<String, dynamic> ? data : {};
            _recentActivity = data['recent_exams'] is List
                ? List<dynamic>.from(data['recent_exams'])
                : [];
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load summary (status ${response.statusCode})';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchJson(String endpoint) async {
    try {
      final response = await _api.get('$endpoint?format=json');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch data (${response.statusCode})'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
    return null;
  }

  Future<void> _downloadCsv(String endpoint, String filename) async {
    try {
      final response = await _api.get('$endpoint?format=csv');
      if (response.statusCode == 200) {
        final csvString = response.body;
        final bytes = utf8.encode(csvString);
        final blob = html.Blob([bytes], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', '$filename.csv')
          ..click();
        html.Url.revokeObjectUrl(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$filename.csv downloaded'),
              backgroundColor: context.colors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed (${response.statusCode})'),
              backgroundColor: context.colors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  void _showJsonDialog(String title, Map<String, dynamic> data) {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: context.colors.border),
        ),
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            maxWidth: MediaQuery.of(ctx).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Icon(Icons.data_object_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 20, color: context.colors.textMuted),
                      onPressed: () => Navigator.of(ctx).pop(),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.colors.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    jsonStr,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.5,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: context.colors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: jsonStr));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('JSON copied to clipboard'),
                            backgroundColor: context.colors.success,
                          ),
                        );
                      },
                      child: Text(
                        'Copy',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                    SizedBox(width: 4),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        'Close',
                        style: TextStyle(color: context.colors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStudentSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => _StudentPickerSheet(
        onSelected: (studentId) {
          Navigator.of(ctx).pop();
          _fetchAndShowStudent(studentId);
        },
      ),
    );
  }

  Future<void> _fetchAndShowStudent(int studentId) async {
    final data = await _fetchJson('/stem/export/student/$studentId');
    if (data != null && mounted) {
      _showJsonDialog('Student #$studentId Data', data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.colors.textPrimary, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Analytics Export',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.colors.textPrimary, size: 20),
            onPressed: _loadSummary,
            splashRadius: 20,
          ),
        ],
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadSummary,
        color: AppColors.primary,
        child: _loading
            ? _buildLoadingShimmer()
            : _error != null
                ? _buildErrorState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          ShimmerLoading.grid(count: 4, childAspectRatio: 1.6),
          SizedBox(height: 16),
          ShimmerLoading.list(count: 1, height: 110),
          SizedBox(height: 16),
          ShimmerLoading.list(count: 5, height: 90),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: context.colors.error),
            SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
            ),
            SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadSummary,
              icon: Icon(Icons.refresh_rounded, size: 16),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          _buildSummaryDashboard(),
          _buildRecentActivity(),
          _buildExportOptions(),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSummaryDashboard() {
    final totalStudents = _summary['total_students'] ?? 0;
    final totalConcepts = _summary['total_concepts'] ?? 0;
    final avgMastery = _summary['avg_mastery'] ?? 0;
    final avgExamScore = _summary['avg_exam_score'] ?? 0;

    final stats = [
      _StatData('Total Students', '$totalStudents', Icons.people_rounded, AppColors.primary),
      _StatData('Total Concepts', '$totalConcepts', Icons.lightbulb_rounded, context.colors.accent),
      _StatData('Avg Mastery', '${avgMastery is num ? avgMastery.round() : 0}%', Icons.trending_up_rounded, context.colors.success),
      _StatData('Avg Exam Score', '${avgExamScore is num ? avgExamScore.round() : 0}%', Icons.quiz_rounded, context.colors.warning),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
        ),
        itemCount: 4,
        itemBuilder: (context, i) {
          final s = stats[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(s.icon, size: 20, color: s.color),
                SizedBox(height: 8),
                Text(
                  s.value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: s.color,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  s.label,
                  style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (_recentActivity.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Recent Activity',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
              ),
            ],
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recentActivity.length,
              separatorBuilder: (_, __) => SizedBox(width: 10),
              itemBuilder: (context, i) {
                final exam = _recentActivity[i];
                final studentName = exam['student_name'] ?? 'Unknown';
                final subject = exam['subject'] ?? '';
                final score = exam['score'] ?? 0;
                final date = exam['date'] ?? '';

                Color scoreColor;
                if (score >= 70) {
                  scoreColor = context.colors.success;
                } else if (score >= 50) {
                  scoreColor = context.colors.warning;
                } else {
                  scoreColor = context.colors.error;
                }

                return Container(
                  width: 160,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        studentName,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subject,
                        style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: scoreColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$score%',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scoreColor),
                            ),
                          ),
                          Text(
                            date,
                            style: TextStyle(fontSize: 10, color: context.colors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOptions() {
    final exports = [
      _ExportOption(
        icon: Icons.people_rounded,
        title: 'Students Progress',
        description: 'All student mastery data across concepts',
        endpoint: '/stem/export/students-progress',
        filename: 'students_progress',
        color: AppColors.primary,
      ),
      _ExportOption(
        icon: Icons.quiz_rounded,
        title: 'Exam Results',
        description: 'Mock exam scores and performance',
        endpoint: '/stem/export/exam-results',
        filename: 'exam_results',
        color: context.colors.warning,
      ),
      _ExportOption(
        icon: Icons.trending_up_rounded,
        title: 'Mastery Summary',
        description: 'Per-concept mastery averages',
        endpoint: '/stem/export/mastery-summary',
        filename: 'mastery_summary',
        color: context.colors.success,
      ),
      _ExportOption(
        icon: Icons.school_rounded,
        title: 'Subject Overview',
        description: 'Per-subject statistics',
        endpoint: '/stem/export/subject-overview',
        filename: 'subject_overview',
        color: context.colors.accent,
      ),
      _ExportOption(
        icon: Icons.person_rounded,
        title: 'Individual Student',
        description: 'Complete data for a single student',
        endpoint: '/stem/export/student',
        filename: 'student_data',
        color: context.colors.info,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.download_rounded, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Download Reports',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...exports.map((e) => _buildExportCard(e)),
        ],
      ),
    );
  }

  Widget _buildExportCard(_ExportOption export) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: export.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(export.icon, size: 18, color: export.color),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      export.title,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      export.description,
                      style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleViewJson(export),
                  icon: Icon(Icons.visibility_rounded, size: 14),
                  label: Text('View JSON', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: context.colors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleDownloadCsv(export),
                  icon: Icon(Icons.download_rounded, size: 14),
                  label: Text('Download CSV', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: AppColors.textOnPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleViewJson(_ExportOption export) async {
    if (export.title == 'Individual Student') {
      _showStudentSelector();
      return;
    }
    final data = await _fetchJson(export.endpoint);
    if (data != null && mounted) {
      _showJsonDialog(export.title, data);
    }
  }

  Future<void> _handleDownloadCsv(_ExportOption export) async {
    if (export.title == 'Individual Student') {
      _showStudentSelectorCsv(export);
      return;
    }
    await _downloadCsv(export.endpoint, export.filename);
  }

  void _showStudentSelectorCsv(_ExportOption export) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => _StudentPickerSheet(
        onSelected: (studentId) {
          Navigator.of(ctx).pop();
          _downloadCsv('${export.endpoint}/$studentId', '${export.filename}_$studentId');
        },
      ),
    );
  }
}

class _StudentPickerSheet extends StatefulWidget {
  final void Function(int studentId) onSelected;

  const _StudentPickerSheet({required this.onSelected});

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  final ApiService _api = ApiService();

  List<dynamic> _students = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      final response = await _api.get('/stem/export/students-progress?format=json');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final students = data is List ? data : (data['students'] is List ? data['students'] : []);
        if (mounted) {
          setState(() {
            _students = List<dynamic>.from(students);
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Select Student',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
          ),
          SizedBox(height: 4),
          Text(
            'Enter a student ID or pick from the list below',
            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
          ),
          SizedBox(height: 14),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Student ID',
              hintStyle: TextStyle(color: context.colors.textMuted),
              filled: true,
              fillColor: context.colors.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.primary),
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primary),
                onPressed: () {
                  final id = int.tryParse(_controller.text.trim());
                  if (id != null) widget.onSelected(id);
                },
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          SizedBox(height: 14),
          Expanded(
            child: _loading
                ? ShimmerLoading.list(count: 4, height: 56)
                : _students.isEmpty
                    ? Center(
                        child: Text(
                          'No students found',
                          style: TextStyle(fontSize: 13, color: context.colors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _students.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: context.colors.border),
                        itemBuilder: (context, i) {
                          final s = _students[i];
                          final id = s['student_id'] ?? s['id'] ?? i;
                          final name = s['student_name'] ?? s['name'] ?? 'Student #$id';
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: context.colors.primaryGlow,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                            ),
                            title: Text(
                              name,
                              style: TextStyle(fontSize: 13, color: context.colors.textPrimary),
                            ),
                            subtitle: Text(
                              'ID: $id',
                              style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.textMuted),
                            onTap: () => widget.onSelected(id is int ? id : int.tryParse('$id') ?? 0),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatData(this.label, this.value, this.icon, this.color);
}

class _ExportOption {
  final IconData icon;
  final String title;
  final String description;
  final String endpoint;
  final String filename;
  final Color color;

  const _ExportOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.endpoint,
    required this.filename,
    required this.color,
  });
}
