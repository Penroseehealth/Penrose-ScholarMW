import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../vtc_theme.dart';

/// Numbered circular badge + serif heading + supporting description.
class VtcSectionHeader extends StatelessWidget {
  const VtcSectionHeader({
    super.key,
    required this.number,
    required this.icon,
    required this.heading,
    required this.description,
  });

  final String number;
  final IconData icon;
  final String heading;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NumberedBadge(number: number, icon: icon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading, style: VtcType.sectionHeading(context)),
                const SizedBox(height: 6),
                Text(description, style: VtcType.body(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberedBadge extends StatelessWidget {
  const _NumberedBadge({required this.number, required this.icon});

  final String number;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $number',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: VtcPalette.electric.withValues(alpha: 0.65), width: 1.4),
                  boxShadow: [BoxShadow(color: VtcPalette.electric.withValues(alpha: 0.22), blurRadius: 16)],
                ),
              ),
              Icon(icon, size: 22, color: VtcPalette.electricBright),
              // Step number, so the order is readable without relying on colour.
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: VtcPalette.gold),
                  alignment: Alignment.center,
                  child: Text(
                    number,
                    style: VtcType.bodyIvory(
                      context,
                    ).copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: VtcPalette.navyDeep),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large translucent text area with a live character counter and a resize grip.
class TextComposer extends StatelessWidget {
  const TextComposer({
    super.key,
    required this.controller,
    required this.onChanged,
    this.maxLength = 300,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxLength;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Semantics(
          textField: true,
          label: 'Text to speak',
          child: TextField(
            key: const ValueKey('vtc-composer'),
            controller: controller,
            enabled: enabled,
            onChanged: onChanged,
            minLines: 5,
            maxLines: 9,
            maxLength: maxLength,
            textCapitalization: TextCapitalization.sentences,
            style: VtcType.bodyIvory(context).copyWith(fontSize: 16.5),
            cursorColor: VtcPalette.gold,
            inputFormatters: [
              // Stop input rather than silently truncating.
              LengthLimitingTextInputFormatter(maxLength),
            ],
            decoration: InputDecoration(
              hintText: 'Type your text here…',
              hintStyle: VtcType.body(context).copyWith(fontSize: 16.5),
              filled: true,
              fillColor: const Color(0x8C0A1130),
              counterText: '',
              contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
              border: _border(VtcPalette.electric.withValues(alpha: 0.38)),
              enabledBorder: _border(VtcPalette.electric.withValues(alpha: 0.38)),
              focusedBorder: _border(VtcPalette.electricBright),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Resize grip affordance.
            const _ResizeGrip(),
            const SizedBox(width: 12),
            Semantics(
              liveRegion: true,
              label: 'Characters used',
              child: Text(
                '${controller.text.characters.length}/$maxLength',
                style: VtcType.body(context).copyWith(fontSize: 12.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: 1.2),
      );
}

/// Diagonal grip lines in the textarea's lower-right corner.
class _ResizeGrip extends StatelessWidget {
  const _ResizeGrip();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(width: 16, height: 16, child: CustomPaint(painter: _GripPainter())),
    );
  }
}

class _GripPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = VtcPalette.ivory.withValues(alpha: 0.35)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final d = 4.0 + i * 4.0;
      canvas.drawLine(Offset(size.width - d, size.height), Offset(size.width, size.height - d), paint);
    }
  }

  @override
  bool shouldRepaint(_GripPainter oldDelegate) => false;
}

/// Gold "Generate Speech" call to action.
class SynthesisButton extends StatefulWidget {
  const SynthesisButton({
    super.key,
    required this.onPressed,
    required this.busy,
    this.label = 'Generate Speech',
    this.busyLabel = 'Synthesizing…',
    this.width = 230,
  });

  final VoidCallback? onPressed;
  final bool busy;
  final String label;
  final String busyLabel;
  final double width;

  @override
  State<SynthesisButton> createState() => _SynthesisButtonState();
}

class _SynthesisButtonState extends State<SynthesisButton> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.busy ? widget.busyLabel : widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: enabled ? widget.onPressed : null,
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 110),
            child: AnimatedOpacity(
              opacity: enabled ? 1.0 : 0.55,
              duration: const Duration(milliseconds: 180),
              child: Container(
                width: widget.width,
                height: 62,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: VtcPalette.goldGradient,
                  boxShadow: [
                    BoxShadow(
                      color: VtcPalette.gold.withValues(alpha: _hovering && enabled ? 0.55 : 0.32),
                      blurRadius: _hovering && enabled ? 28 : 18,
                      spreadRadius: -2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.busy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(VtcPalette.navyDeep),
                        ),
                      )
                    else
                      const Icon(Icons.graphic_eq_rounded, size: 20, color: VtcPalette.navyDeep),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.busy ? widget.busyLabel : widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VtcType.bodyIvory(
                          context,
                        ).copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: VtcPalette.navyDeep),
                      ),
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
}

/// Small dark-blue glass card with a gold heading and lightbulb icon.
class ProTipCard extends StatelessWidget {
  const ProTipCard({
    super.key,
    this.title = 'Pro Tip',
    this.body = 'Use short, clear sentences\nfor a more natural and\naccurate voice synthesis.',
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0x66101A44),
        border: Border.all(color: VtcPalette.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, size: 20, color: VtcPalette.goldLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: VtcType.bodyIvory(
                    context,
                  ).copyWith(fontSize: 14.5, fontWeight: FontWeight.w600, color: VtcPalette.goldLight),
                ),
                const SizedBox(height: 5),
                Text(body, style: VtcType.bodyIvory(context).copyWith(fontSize: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
