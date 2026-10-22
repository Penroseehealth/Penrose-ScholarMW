import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'voice_catalog.dart';
import 'vtc_theme.dart';

/// Premium searchable, scrollable accent/voice dropdown.
///
/// Built from a real overlay rather than `DropdownButton` so it can show
/// region-code badges, gender badges, per-voice preview and a search field, and
/// so the list can extend past the visible area with its own scrollbar.
class AccentSelector extends StatefulWidget {
  const AccentSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.onPreview,
  });

  final List<VoiceOption> options;
  final VoiceOption? selected;
  final ValueChanged<VoiceOption> onChanged;
  final bool enabled;

  /// Optional per-voice audition. When null the preview buttons are hidden.
  final ValueChanged<VoiceOption>? onPreview;

  @override
  State<AccentSelector> createState() => _AccentSelectorState();
}

class _AccentSelectorState extends State<AccentSelector> {
  final GlobalKey _buttonKey = GlobalKey();
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _menuScroll = ScrollController();
  OverlayEntry? _entry;
  String? _query;

  @override
  void dispose() {
    _close();
    _search.dispose();
    _searchFocus.dispose();
    _menuScroll.dispose();
    super.dispose();
  }

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  void _toggle() {
    if (_entry != null) {
      _close();
      return;
    }
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final anchor = box.localToGlobal(Offset.zero);
    _query = '';
    _search.clear();
    setState(() {});

    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (context) => _AccentMenu(
        anchor: anchor,
        width: box.size.width,
        options: widget.options,
        selected: widget.selected,
        query: _query ?? '',
        onQueryChanged: (v) {
          _query = v;
          // Rebuild just the menu contents.
          _entry?.markNeedsBuild();
          setState(() {});
        },
        searchController: _search,
        searchFocus: _searchFocus,
        scrollController: _menuScroll,
        onSelected: (option) {
          _close();
          widget.onChanged(option);
        },
        onPreview: widget.onPreview,
        onDismiss: _close,
      ),
    );
    overlay.insert(_entry!);
    // Let the menu mount before taking focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_entry != null) _searchFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: 'Accent and voice selector',
      value: selected == null ? 'None selected' : selected.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: widget.enabled ? _toggle : null,
          child: Container(
            key: _buttonKey,
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0x66101733),
              border: Border.all(
                color: widget.enabled
                    ? VtcPalette.electric.withValues(alpha: 0.45)
                    : VtcPalette.ivory.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                if (selected != null) ...[
                  _RegionBadge(code: selected.regionCode, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: VtcType.bodyIvory(context).copyWith(fontSize: 15.5, fontWeight: FontWeight.w500),
                        ),
                        if (selected.note != null)
                          Text(
                            selected.note!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VtcType.body(context).copyWith(fontSize: 12.5),
                          ),
                      ],
                    ),
                  ),
                ] else
                  Expanded(child: Text('Select an accent and voice', style: VtcType.body(context))),
                const Icon(Icons.keyboard_arrow_down_rounded, color: VtcPalette.ivoryDim, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The floating menu itself.
class _AccentMenu extends StatelessWidget {
  const _AccentMenu({
    required this.anchor,
    required this.width,
    required this.options,
    required this.selected,
    required this.query,
    required this.onQueryChanged,
    required this.searchController,
    required this.searchFocus,
    required this.scrollController,
    required this.onSelected,
    required this.onDismiss,
    this.onPreview,
  });

  final Offset anchor;
  final double width;
  final List<VoiceOption> options;
  final VoiceOption? selected;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final TextEditingController searchController;
  final FocusNode searchFocus;

  /// Explicit because the menu is mounted in an [OverlayEntry], which sits
  /// above the app's [PrimaryScrollController].
  final ScrollController scrollController;
  final ValueChanged<VoiceOption> onSelected;
  final VoidCallback onDismiss;
  final ValueChanged<VoiceOption>? onPreview;

  static const double _maxHeight = 340;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final results = VoiceCatalog.filter(options, query);
    // Keep the menu on screen on short/narrow viewports.
    final below = media.size.height - (anchor.dy + 62) - 12;
    final above = anchor.dy - 12;
    final openUpwards = below < 220 && above > below;
    final height = _maxHeight.clamp(160.0, openUpwards ? above : below);
    final widthClamped = width.clamp(240.0, media.size.width - 24);
    final left = anchor.dx.clamp(12.0, media.size.width - widthClamped - 12);
    final top = openUpwards ? anchor.dy - height - 8 : anchor.dy + 70;

    return Stack(
      children: [
        // Tap-away scrim.
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onDismiss, child: const SizedBox.expand()),
        ),
        // Escape dismisses, for keyboard users.
        Positioned.fill(
          child: Shortcuts(
            shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): _DismissIntent()},
            child: Actions(
              actions: {
                _DismissIntent: CallbackAction<_DismissIntent>(
                  onInvoke: (_) {
                    onDismiss();
                    return null;
                  },
                ),
              },
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned(
          left: left,
          top: top.clamp(8.0, media.size.height - height - 8),
          width: widthClamped,
          height: height,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xF2151D45), Color(0xF4080C26)],
                ),
                border: Border.all(color: VtcPalette.electric.withValues(alpha: 0.5)),
                boxShadow: [BoxShadow(color: const Color(0x99000000), blurRadius: 40, offset: const Offset(0, 18))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    _SearchField(controller: searchController, focusNode: searchFocus, onChanged: onQueryChanged),
                    Expanded(
                      child: results.isEmpty
                          ? Center(child: Text('No accent matches “$query”.', style: VtcType.body(context)))
                          : Scrollbar(
                              // The list deliberately overflows so the
                              // scrollbar is always meaningful. The controller
                              // is explicit because this menu lives in an
                              // OverlayEntry, above any PrimaryScrollController.
                              controller: scrollController,
                              thumbVisibility: true,
                              child: ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                itemCount: results.length,
                                itemBuilder: (context, i) => _OptionRow(
                                  option: results[i],
                                  isSelected: results[i].id == selected?.id,
                                  onTap: () => onSelected(results[i]),
                                  onPreview: onPreview == null ? null : () => onPreview!(results[i]),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode, required this.onChanged});

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: VtcPalette.electric.withValues(alpha: 0.3))),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: VtcType.bodyIvory(context).copyWith(fontSize: 15),
        cursorColor: VtcPalette.gold,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search accent or language…',
          hintStyle: VtcType.body(context).copyWith(fontSize: 14.5),
          prefixIcon: const Icon(Icons.search_rounded, size: 19, color: VtcPalette.ivoryDim),
          prefixIconConstraints: const BoxConstraints(minWidth: 32),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.isSelected, required this.onTap, this.onPreview});

  final VoiceOption option;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${option.label}, ${option.region}',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? VtcPalette.electric.withValues(alpha: 0.22) : Colors.transparent,
                border: Border(
                  left: BorderSide(width: 3, color: isSelected ? VtcPalette.electricBright : Colors.transparent),
                ),
              ),
              child: Row(
                children: [
                  _RegionBadge(code: option.regionCode, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                option.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: VtcType.bodyIvory(
                                  context,
                                ).copyWith(fontSize: 14.5, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _GenderBadge(gender: option.gender),
                          ],
                        ),
                        if (option.note != null)
                          Text(
                            option.note!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VtcType.body(context).copyWith(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  if (onPreview != null)
                    IconButton(
                      onPressed: onPreview,
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      color: VtcPalette.goldLight,
                      iconSize: 21,
                      tooltip: 'Preview ${option.label}',
                      visualDensity: VisualDensity.compact,
                    ),
                  // Selection is not conveyed by colour alone: a checkmark.
                  SizedBox(
                    width: 26,
                    child:
                        isSelected ? const Icon(Icons.check_rounded, size: 19, color: VtcPalette.electricBright) : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderBadge extends StatelessWidget {
  const _GenderBadge({required this.gender});

  final String gender;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: VtcPalette.violet.withValues(alpha: 0.55),
        border: Border.all(color: VtcPalette.ivory.withValues(alpha: 0.18)),
      ),
      child: Text(
        gender,
        style: VtcType.body(context).copyWith(fontSize: 11, letterSpacing: 0.4, color: VtcPalette.ivory),
      ),
    );
  }
}

/// ISO region code chip, e.g. "US" / "GB" / "SA".
///
/// Replaces the flag emoji the catalogue used to carry: Flutter web ships only
/// Roboto, which has no regional-indicator glyphs, so emoji flags rendered as
/// tofu boxes and logged "Could not find a set of Noto fonts" on every build.
/// The fixed width keeps the row from reflowing between 2- and 3-letter codes.
class _RegionBadge extends StatelessWidget {
  const _RegionBadge({required this.code, required this.size});

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.7,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: VtcPalette.ivory.withValues(alpha: 0.22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [VtcPalette.electric.withValues(alpha: 0.28), VtcPalette.violet.withValues(alpha: 0.22)],
        ),
      ),
      child: Text(
        code,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: VtcType.body(
          context,
        ).copyWith(fontSize: size * 0.52, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: VtcPalette.ivory),
      ),
    );
  }
}
