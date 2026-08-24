import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/services.dart';
import '../../core/theme/theme_colors.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _debounce;
  bool _loading = false;
  String? _error;
  String _query = '';
  List<dynamic> _results = [];
  bool _hasSearched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final trimmed = value.trim();
      if (trimmed.length < 2) {
        setState(() {
          _results = [];
          _hasSearched = false;
          _query = '';
        });
        return;
      }
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _loading = true;
      _error = null;
      _query = query;
      _hasSearched = true;
    });

    try {
      final response = await _api.get('/search?q=${Uri.encodeQueryComponent(query)}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _results = body is List ? body : (body['results'] ?? []);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Search failed. Please try again.';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An error occurred: $e';
          _loading = false;
        });
      }
    }
  }

  Map<String, List<dynamic>> _groupResults() {
    final map = <String, List<dynamic>>{};
    for (final item in _results) {
      final type = item['type'] ?? 'other';
      map.putIfAbsent(type, () => []).add(item);
    }
    return map;
  }

  String _groupTitle(String type) {
    switch (type) {
      case 'course':
        return 'Courses';
      case 'assessment':
        return 'Assessments';
      case 'resource':
        return 'Resources';
      case 'research':
        return 'Research';
      case 'user':
        return 'People';
      case 'lesson':
        return 'Lessons';
      default:
        return type[0].toUpperCase() + type.substring(1).replaceAll('_', ' ');
    }
  }

  IconData _groupIcon(String type) {
    switch (type) {
      case 'course':
        return Icons.book_outlined;
      case 'assessment':
        return Icons.quiz_outlined;
      case 'resource':
        return Icons.folder_open_outlined;
      case 'research':
        return Icons.science_outlined;
      case 'user':
        return Icons.person_outline;
      case 'lesson':
        return Icons.school_outlined;
      default:
        return Icons.search;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Find courses, assessments, resources & more',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search everything...',
                        hintStyle:
                            TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                        prefixIcon: const Icon(Icons.search,
                            color: Colors.white70, size: 22),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Colors.white70, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _results = [];
                                    _query = '';
                                    _hasSearched = false;
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.15),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (!_hasSearched) {
      return _buildInitialState();
    }

    if (_results.isEmpty) {
      return _buildNoResults();
    }

    return _buildResults();
  }

  Widget _buildInitialState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 56, color: context.colors.textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'Type to search',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Search across courses, assessments, and resources',
              style: TextStyle(fontSize: 13, color: context.colors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: context.colors.textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'No results for "$_query"',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try different keywords or check your spelling',
              style: TextStyle(fontSize: 13, color: context.colors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final grouped = _groupResults();
    final totalResults = _results.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '$totalResults result${totalResults == 1 ? '' : 's'} for "$_query"',
          style: TextStyle(
            fontSize: 13,
            color: context.colors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in grouped.entries) ...[
          Row(
            children: [
              Icon(_groupIcon(entry.key),
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                '${_groupTitle(entry.key)} (${entry.value.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...entry.value.map((item) => _buildResultItem(item)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildResultItem(dynamic item) {
    final title = item['title'] ?? '';
    final subtitle = item['subtitle'] ?? '';
    final type = item['type'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_groupIcon(type), color: AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                style: TextStyle(
                    fontSize: 12, color: context.colors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing:
            Icon(Icons.chevron_right, size: 18, color: context.colors.textSecondary),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.colors.error),
            const SizedBox(height: 12),
            Text(
              _error!,
              style:
                  TextStyle(fontSize: 14, color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _performSearch(_query),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
