import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_colors.dart';
import '../../../services/api_service.dart';

/// Read-only dev viewer for mathsdrill progress mirrored to the Penrose API.
///
/// The embedded mathsdrill app POSTs completed drills and past-paper question
/// states to `/api/v1/mathsdrill/*`. This screen lists what has been stored so
/// the mirror is visible while the feature is developed.
class MathsdrillProgressScreen extends StatefulWidget {
  const MathsdrillProgressScreen({super.key});

  @override
  State<MathsdrillProgressScreen> createState() => _MathsdrillProgressScreenState();
}

class _MathsdrillProgressScreenState extends State<MathsdrillProgressScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _students = const [];
  List<Map<String, dynamic>> _sessions = const [];
  String? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final studentsRes = await _api.get('/mathsdrill/students');
      if (studentsRes.statusCode != 200) {
        throw Exception('students ${studentsRes.statusCode}');
      }
      final students = (jsonDecode(studentsRes.body) as List).cast<Map<String, dynamic>>();
      final sessionsRes = await _api.get('/mathsdrill/sessions');
      if (sessionsRes.statusCode != 200) {
        throw Exception('sessions ${sessionsRes.statusCode}');
      }
      final sessions = (jsonDecode(sessionsRes.body) as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _students = students;
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load mathsdrill progress: $e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visibleSessions {
    final name = _selected;
    if (name == null) return _sessions;
    return _sessions.where((s) => s['student_name'] == name).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.colors;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/mathsdrill'),
          tooltip: 'Back to Mathsdrill',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded, color: t.teal, size: 20),
            const SizedBox(width: 8),
            Text('Mathsdrill Progress', style: TextStyle(color: t.textPrimary, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(t),
    );
  }

  Widget _buildBody(ThemeColors t) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: t.textMuted),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: t.textSecondary)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No mathsdrill progress recorded yet. Complete a drill inside the mathsdrill app '
            'and it will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textSecondary),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_students.isNotEmpty) _buildStudentChips(t),
        Expanded(child: _buildSessionList(t)),
      ],
    );
  }

  Widget _buildStudentChips(ThemeColors t) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(t, 'All', _selected == null, () => setState(() => _selected = null)),
            for (final s in _students)
              _chip(
                t,
                '${s['student_name']} (${s['sessions']})',
                _selected == s['student_name'],
                () => setState(() => _selected = s['student_name'] as String?),
              ),
          ],
        ),
      );

  Widget _chip(ThemeColors t, String label, bool active, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? t.teal.withValues(alpha: 0.18) : t.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? t.teal : t.border),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: active ? t.teal : t.textSecondary),
          ),
        ),
      );

  Widget _buildSessionList(ThemeColors t) {
    final sessions = _visibleSessions;
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final s = sessions[i];
        final correct = (s['correct'] ?? 0) as int;
        final total = (s['total'] ?? 0) as int;
        final pct = total > 0 ? (100 * correct / total).round() : 0;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: pct >= 60 ? t.success : t.warning,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s['student_name']}',
                      style: TextStyle(fontWeight: FontWeight.w600, color: t.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s['topic_id'] ?? 'unknown topic'} · $correct/$total',
                      style: TextStyle(fontSize: 12, color: t.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(s['created_at']),
                style: TextStyle(fontSize: 11, color: t.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(Object? value) {
    if (value is! String) return '';
    final dt = DateTime.tryParse(value);
    if (dt == null) return value;
    final local = dt.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm $hh:$mi';
  }
}
