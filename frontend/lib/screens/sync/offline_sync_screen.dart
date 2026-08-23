import 'dart:convert';

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/services.dart';
import '../../core/theme/theme_colors.dart';

class OfflineSyncScreen extends StatefulWidget {
  OfflineSyncScreen({super.key});

  @override
  State<OfflineSyncScreen> createState() => _OfflineSyncScreenState();
}

class _OfflineSyncScreenState extends State<OfflineSyncScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  bool _syncing = false;
  String? _error;

  int _pendingCount = 0;
  int _syncedCount = 0;
  int _conflictCount = 0;

  List<dynamic> _syncHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final statusRes = await _api.get('/sync/status');
      final pullRes = await _api.get(
        '/sync/pull?since=${DateTime.now().toUtc().subtract(Duration(days: 7)).toIso8601String()}',
      );

      if (!mounted) return;

      if (statusRes.statusCode == 200) {
        final body = jsonDecode(statusRes.body);
        setState(() {
          _pendingCount = body['pending'] ?? 0;
          _syncedCount = body['synced'] ?? 0;
          _conflictCount = body['conflicts'] ?? 0;
        });
      }

      if (pullRes.statusCode == 200) {
        final pullBody = jsonDecode(pullRes.body);
        setState(() {
          _syncHistory = pullBody is List ? pullBody : (pullBody['records'] ?? []);
        });
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An error occurred: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _pushSync() async {
    setState(() {
      _syncing = true;
      _error = null;
    });

    try {
      final response = await _api.post(
        '/sync/push',
        body: {'records': []},
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync completed successfully'),
            backgroundColor: context.colors.success,
          ),
        );
        await _loadData();
      } else {
        setState(() {
          _error = 'Sync failed. Please try again.';
          _syncing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An error occurred: $e';
          _syncing = false;
        });
      }
    }
  }

  Future<void> _resolveConflict(
      String recordId, String resolution, Map<String, dynamic> merged) async {
    try {
      final response = await _api.post(
        '/sync/resolve',
        body: {
          'record_id': recordId,
          'resolution': resolution,
          'merged_payload': merged,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resolution == 'keep_local'
                  ? 'Local version kept'
                  : resolution == 'keep_remote'
                      ? 'Remote version kept'
                      : 'Conflict resolved with merge',
            ),
            backgroundColor: context.colors.success,
          ),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve conflict')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred')),
        );
      }
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'synced':
        return context.colors.success;
      case 'pending':
        return context.colors.warning;
      case 'conflict':
        return context.colors.error;
      default:
        return context.colors.textSecondary;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'synced':
        return Icons.cloud_done_outlined;
      case 'pending':
        return Icons.cloud_upload_outlined;
      case 'conflict':
        return Icons.sync_problem_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 70,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Offline Sync',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage data synchronisation & conflicts',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _syncedCount == 0 && _pendingCount == 0) {
      return _buildErrorState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Sync Status'),
        SizedBox(height: 8),
        _buildStatusOverview(),
        SizedBox(height: 12),
        _buildSyncButton(),
        if (_error != null) ...[
          SizedBox(height: 8),
          _buildErrorBanner(),
        ],
        SizedBox(height: 20),
        _buildSectionHeader('Sync History'),
        SizedBox(height: 8),
        _buildSyncHistory(),
        if (_conflictCount > 0) ...[
          SizedBox(height: 20),
          _buildSectionHeader('Conflicts'),
          SizedBox(height: 8),
          _buildConflictResolution(),
        ],
      ],
    );
  }

  Widget _buildStatusOverview() {
    return Row(
      children: [
        Expanded(
          child: _buildStatusCard(
            label: 'Pending',
            value: '$_pendingCount',
            icon: Icons.cloud_upload_outlined,
            color: context.colors.warning,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildStatusCard(
            label: 'Synced',
            value: '$_syncedCount',
            icon: Icons.cloud_done_outlined,
            color: context.colors.success,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildStatusCard(
            label: 'Conflicts',
            value: '$_conflictCount',
            icon: Icons.sync_problem_outlined,
            color: context.colors.error,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _syncing ? null : _pushSync,
        icon: _syncing
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(Icons.sync, size: 20),
        label: Text(_syncing ? 'Syncing...' : 'Sync Now'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Card(
      color: context.colors.error.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: context.colors.error, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(
                    fontSize: 13, color: context.colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncHistory() {
    if (_syncHistory.isEmpty) {
      return _buildEmptyCard('No sync history in the last 7 days');
    }

    return Column(
      children: _syncHistory.map((record) {
        final status = record['status'] ?? 'unknown';
        final entityType = record['entity_type'] ?? '';
        final entityId = record['entity_id'] ?? '';
        final action = record['action'] ?? '';
        final syncedAt = record['synced_at'] ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _statusIcon(status),
                color: _statusColor(status),
                size: 20,
              ),
            ),
            title: Text(
              '$entityType #$entityId',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${action.toUpperCase()} · $syncedAt',
              style: TextStyle(
                  fontSize: 12, color: context.colors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: _statusColor(status),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConflictResolution() {
    final conflicts =
        _syncHistory.where((r) => r['status'] == 'conflict').toList();

    if (conflicts.isEmpty) {
      return _buildEmptyCard('No conflicts to resolve');
    }

    return Column(
      children: conflicts.map((record) {
        final entityType = record['entity_type'] ?? '';
        final entityId = record['entity_id'] ?? '';
        final payload = record['payload'] ?? {};
        final recordId = record['id'] ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sync_problem_outlined,
                        color: context.colors.error, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$entityType #$entityId',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _resolveConflict(recordId, 'keep_local', payload),
                        icon: Icon(Icons.phone_android, size: 16),
                        label: Text('Keep Local',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colors.info,
                          side: BorderSide(color: context.colors.info),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _resolveConflict(recordId, 'keep_remote', payload),
                        icon: Icon(Icons.cloud_outlined, size: 16),
                        label: Text('Keep Remote',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colors.success,
                          side: BorderSide(color: context.colors.success),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _resolveConflict(recordId, 'merge', payload),
                        icon: Icon(Icons.merge, size: 16),
                        label: Text('Merge',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colors.secondary,
                          side: BorderSide(color: context.colors.secondary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Shared Widgets ──────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: context.colors.textPrimary,
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            style:
                TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: context.colors.error),
            SizedBox(height: 12),
            Text(
              _error!,
              style:
                  TextStyle(fontSize: 14, color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
