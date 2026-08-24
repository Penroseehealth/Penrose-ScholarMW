import 'package:flutter/material.dart';
import '../core/theme/theme_colors.dart';

class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
    this.margin,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();

  static Widget grid({int count = 6, double childAspectRatio = 1.6}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: count,
          itemBuilder: (_, __) => const ShimmerLoading(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 14,
          ),
        ),
      );

  static Widget list({int count = 5, double height = 80}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: List.generate(
            count,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ShimmerLoading(
                width: double.infinity,
                height: height,
                borderRadius: 14,
              ),
            ),
          ),
        ),
      );
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => Container(
          margin: widget.margin,
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                context.colors.surfaceElevated,
                context.colors.surfaceHighest,
                context.colors.surfaceElevated,
              ],
              stops: [
                (_animation.value - 1).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 1).clamp(0.0, 1.0),
              ],
            ),
          ),
        ),
      );
}

class ShimmerListTile extends StatelessWidget {
  const ShimmerListTile({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: Row(
          children: [
            const ShimmerLoading(width: 44, height: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoading(
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: 14,
                    borderRadius: 7,
                  ),
                  const SizedBox(height: 8),
                  ShimmerLoading(
                    width: MediaQuery.of(context).size.width * 0.3,
                    height: 12,
                    borderRadius: 6,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
