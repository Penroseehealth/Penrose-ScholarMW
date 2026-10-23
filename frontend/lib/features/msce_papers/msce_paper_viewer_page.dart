import 'package:flutter/material.dart';

import '../../core/theme/theme_colors.dart';
import 'msce_papers_controller.dart';

/// Reads one paper page by page.
///
/// The pages are rendered by the server and shown as images, so the paper is
/// read in place: nothing is saved to the device and there is no download.
class MscePaperViewerPage extends StatefulWidget {
  const MscePaperViewerPage({super.key, required this.paper});

  final MscePaper paper;

  @override
  State<MscePaperViewerPage> createState() => _MscePaperViewerPageState();
}

class _MscePaperViewerPageState extends State<MscePaperViewerPage> {
  late final PageController _pages;
  int _current = 0;

  int get _pageCount => widget.paper.pages < 1 ? 1 : widget.paper.pages;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= _pageCount) return;
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.paper.year ?? ''} ${widget.paper.subject ?? ''} ${widget.paper.paperLabel}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(widget.paper.subjectNumber, style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
            ],
          ),
          backgroundColor: context.colors.surface,
          foregroundColor: context.colors.textPrimary,
          elevation: 0,
          actions: [
            IconButton(tooltip: 'Paper details', icon: const Icon(Icons.info_outline_rounded), onPressed: _showDetails),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _pageCount,
                  onPageChanged: (index) => setState(() => _current = index),
                  itemBuilder: (context, index) => _buildPage(index),
                ),
              ),
              _buildToolbar(context),
            ],
          ),
        ),
      );

  Widget _buildPage(int index) {
    final url = mscePageUrl(widget.paper.id, index + 1);
    return Container(
      color: context.colors.background,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'Rendering page ${index + 1}…',
                      style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                    ),
                  ],
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_not_supported_outlined, size: 40, color: context.colors.error),
                    const SizedBox(height: 12),
                    Text(
                      'This page could not be shown.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'It may still be being prepared on the server.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous page',
              onPressed: _current > 0 ? () => _goTo(_current - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Page ${_current + 1} of $_pageCount',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: _current.toDouble().clamp(0, (_pageCount - 1).toDouble()),
                      max: (_pageCount - 1).toDouble(),
                      onChanged: _pageCount <= 1 ? null : (value) => _goTo(value.round()),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: _current < _pageCount - 1 ? () => _goTo(_current + 1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      );

  void _showDetails() {
    final paper = widget.paper;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paper.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                _detailRow(context, 'Subject number', paper.subjectNumber.isEmpty ? '—' : paper.subjectNumber),
                _detailRow(context, 'Pages', '${paper.pages}'),
                _detailRow(
                    context, 'Verification', paper.verified ? 'Verified against the MANEB header' : 'Not verified'),
                _detailRow(context, 'Published by', paper.attribution ?? 'Malawi National Examinations Board (MANEB)'),
                _detailRow(context, 'Archive', paper.sourceProvider ?? '—'),
                _detailRow(context, 'Licence', paper.licence ?? 'Educational use'),
                if (paper.sha256 != null) _detailRow(context, 'SHA-256', paper.sha256!.substring(0, 16)),
                const SizedBox(height: 10),
                Text(
                  'The paper is displayed page by page from the server. Nothing is saved '
                  'to this device.',
                  style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 118,
              child: Text(label, style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
              ),
            ),
          ],
        ),
      );
}
