import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import 'msce_paper_viewer_page.dart';
import 'msce_papers_controller.dart';

/// The MSCE past-paper library: every paper MANEB published that the
/// harvester could verify, opened inline in the app.
class MscePapersPage extends StatefulWidget {
  const MscePapersPage({super.key, this.controller});

  /// Injectable for tests; the page builds its own controller otherwise.
  final MscePapersController? controller;

  @override
  State<MscePapersPage> createState() => _MscePapersPageState();
}

class _MscePapersPageState extends State<MscePapersPage> {
  late final MscePapersController _controller;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? MscePapersController();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<MscePapersController>.value(
        value: _controller,
        child: Consumer<MscePapersController>(
          builder: (context, controller, _) => Scaffold(
            backgroundColor: context.colors.background,
            appBar: AppBar(
              title: const Text('MSCE Past Papers'),
              backgroundColor: context.colors.surface,
              foregroundColor: context.colors.textPrimary,
              elevation: 0,
            ),
            body: SafeArea(
              child: controller.loading && controller.all.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(context, controller),
            ),
          ),
        ),
      );

  Widget _buildBody(BuildContext context, MscePapersController controller) {
    if (controller.error != null && controller.all.isEmpty) {
      return _buildError(context, controller);
    }
    final papers = _applyQuery(controller.filtered);
    return Column(
      children: [
        _buildHeader(context, controller),
        if (controller.all.isEmpty)
          Expanded(child: _buildEmpty(context, controller))
        else
          Expanded(
            child: papers.isEmpty
                ? _buildNoMatches(context, controller)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    itemCount: papers.length,
                    itemBuilder: (context, index) => _buildPaperCard(context, papers[index]),
                  ),
          ),
      ],
    );
  }

  List<MscePaper> _applyQuery(List<MscePaper> papers) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return papers;
    return papers
        .where((paper) =>
            paper.title.toLowerCase().contains(query) ||
            (paper.subject ?? '').toLowerCase().contains(query) ||
            (paper.year?.toString() ?? '').contains(query) ||
            paper.subjectNumber.toLowerCase().contains(query))
        .toList(growable: false);
  }

  Widget _buildHeader(BuildContext context, MscePapersController controller) {
    final counts = controller.countsByYear;
    return Container(
      width: double.infinity,
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 18, color: context.colors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Official MANEB papers, verified against the board header',
                  style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            style: TextStyle(fontSize: 14, color: context.colors.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search year, subject or paper number',
              hintStyle: TextStyle(fontSize: 13, color: context.colors.textMuted),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: context.colors.textMuted),
              filled: true,
              fillColor: context.colors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildFilterChips(context, controller),
          if (controller.years.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildYearChip(context, controller, null, 'All years', null),
                  for (final year in controller.years) _buildYearChip(context, controller, year, '$year', counts[year]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildYearChip(
    BuildContext context,
    MscePapersController controller,
    int? year,
    String label,
    int? count,
  ) {
    final selected = controller.selectedYear == year;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        showCheckmark: false,
        label: Text(count == null ? label : '$label ($count)'),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.textOnPrimary : context.colors.textSecondary,
        ),
        backgroundColor: context.colors.background,
        selectedColor: AppColors.primary,
        side: BorderSide(color: selected ? AppColors.primary : context.colors.border),
        onSelected: (_) => controller.setYear(year),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, MscePapersController controller) {
    final chips = <Widget>[];
    for (final subject in controller.subjects) {
      final selected = controller.selectedSubject == subject;
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            selected: selected,
            showCheckmark: false,
            avatar: Icon(
              subject == 'Biology' ? Icons.biotech_rounded : Icons.functions_rounded,
              size: 15,
              color: selected ? AppColors.textOnPrimary : AppColors.primary,
            ),
            label: Text(subject),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.textOnPrimary : context.colors.textSecondary,
            ),
            backgroundColor: context.colors.background,
            selectedColor: AppColors.primary,
            side: BorderSide(color: selected ? AppColors.primary : context.colors.border),
            onSelected: (value) => controller.setSubject(value ? subject : null),
          ),
        ),
      );
    }
    for (final paper in const <int>[1, 2]) {
      final selected = controller.selectedPaper == paper;
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            selected: selected,
            showCheckmark: false,
            label: Text(paper == 1 ? 'Paper I' : 'Paper II'),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.textOnPrimary : context.colors.textSecondary,
            ),
            backgroundColor: context.colors.background,
            selectedColor: AppColors.primary,
            side: BorderSide(color: selected ? AppColors.primary : context.colors.border),
            onSelected: (value) => controller.setPaper(value ? paper : null),
          ),
        ),
      );
    }
    return Wrap(children: chips);
  }

  Widget _buildPaperCard(BuildContext context, MscePaper paper) {
    final isBiology = paper.subject == 'Biology';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        key: ValueKey<String>('paper-${paper.id}'),
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MscePaperViewerPage(paper: paper),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isBiology ? context.colors.teal.withValues(alpha: 0.14) : AppColors.primaryMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isBiology ? Icons.biotech_rounded : Icons.functions_rounded,
                    color: isBiology ? context.colors.teal : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${paper.year ?? '—'}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            paper.paperLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          if (paper.subjectNumber.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              paper.subjectNumber,
                              style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        paper.subject ?? 'Examination paper',
                        style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.description_outlined, size: 13, color: context.colors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '${paper.pages} page${paper.pages == 1 ? '' : 's'}',
                            style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.verified_rounded, size: 13, color: context.colors.success),
                          const SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: TextStyle(fontSize: 11, color: context.colors.success),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, MscePapersController controller) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_rounded, size: 48, color: context.colors.textMuted),
              const SizedBox(height: 14),
              Text(
                controller.harvesting ? 'Preparing the paper library…' : 'No papers yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                controller.harvesting
                    ? 'The papers are being fetched from their public archives and checked '
                        'against the MANEB exam header. This happens once.'
                    : 'The paper library is empty. Run tools/harvest_msce_papers.py to '
                        'download and verify the papers.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => controller.load(refresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Check again'),
              ),
            ],
          ),
        ),
      );

  Widget _buildNoMatches(BuildContext context, MscePapersController controller) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 44, color: context.colors.textMuted),
              const SizedBox(height: 12),
              Text(
                'No paper matches these filters',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () {
                  controller.clearFilters();
                  setState(() => _query = '');
                },
                child: const Text('Clear filters'),
              ),
            ],
          ),
        ),
      );

  Widget _buildError(BuildContext context, MscePapersController controller) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 44, color: context.colors.error),
              const SizedBox(height: 12),
              Text(
                'Could not load the paper library',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                controller.error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => controller.load(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}
