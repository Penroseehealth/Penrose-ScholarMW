import 'dart:math';
import 'package:flutter/material.dart';

import '../math_viz/geometric_shapes.dart';

/// Convenience factory for common geometric shapes.
/// Wraps [GeometricShapeRenderer] with builder methods.
class GeometryEngine {
  /// Render a circle with center and radius.
  static Widget circle({
    double radius = 1.0,
    Offset center = Offset.zero,
    String? label,
    Color color = Colors.cyanAccent,
    bool showCenter = true,
    bool showRadius = false,
    double? width,
    double? height,
  }) =>
      GeometricShapeRenderer(
        shapes: [
          GeometricShape(
            type: ShapeType.circle,
            label: label,
            color: color,
            points: [center],
            radius: radius,
          ),
        ],
        width: width,
        height: height ?? 220,
      );

  /// Render a triangle from three vertices.
  static Widget triangle({
    List<Offset>? vertices,
    String? label,
    Color color = Colors.cyanAccent,
    bool isRightTriangle = false,
    List<LineLabel>? labels,
    double? width,
    double? height,
  }) {
    final pts = vertices ?? [const Offset(-0.8, -0.6), const Offset(0.8, -0.6), const Offset(0, 0.8)];
    return GeometricShapeRenderer(
      shapes: [
        GeometricShape(
          type: isRightTriangle ? ShapeType.rightTriangle : ShapeType.triangle,
          label: label,
          color: color,
          points: pts,
          labels: labels,
        ),
      ],
      width: width,
      height: height ?? 250,
    );
  }

  /// Render a quadrilateral (rectangle, parallelogram, trapezium, etc.).
  static Widget quadrilateral({
    List<Offset>? vertices,
    String? label,
    Color color = Colors.cyanAccent,
    ShapeType shapeType = ShapeType.quadrilateral,
    double? width,
    double? height,
  }) {
    final pts = vertices ??
        [const Offset(-0.8, -0.6), const Offset(0.8, -0.6), const Offset(0.8, 0.6), const Offset(-0.8, 0.6)];
    return GeometricShapeRenderer(
      shapes: [
        GeometricShape(
          type: shapeType,
          label: label,
          color: color,
          points: pts,
        ),
      ],
      width: width,
      height: height ?? 250,
    );
  }

  /// Render a semicircle.
  static Widget semicircle({
    double radius = 1.0,
    Offset center = Offset.zero,
    String? label,
    Color color = Colors.cyanAccent,
    double? width,
    double? height,
  }) =>
      GeometricShapeRenderer(
        shapes: [
          GeometricShape(
            type: ShapeType.semicircle,
            label: label,
            color: color,
            points: [center],
            radius: radius,
          ),
        ],
        width: width,
        height: height ?? 220,
      );

  /// Render a regular polygon with n sides.
  static Widget polygon({
    int sides = 5,
    String? label,
    Color color = Colors.cyanAccent,
    double? width,
    double? height,
  }) {
    final pts = List.generate(sides, (i) {
      final angle = 2 * pi * i / sides - pi / 2;
      return Offset(cos(angle), sin(angle));
    });
    return GeometricShapeRenderer(
      shapes: [
        GeometricShape(
          type: ShapeType.polygon,
          label: label,
          color: color,
          points: pts,
        ),
      ],
      width: width,
      height: height ?? 250,
    );
  }

  /// Render an angle between two lines.
  static Widget angle({
    required Offset vertex,
    required Offset p1,
    required Offset p2,
    String? label,
    Color color = Colors.cyanAccent,
    List<ArcAnnotation>? arcs,
    double? width,
    double? height,
  }) =>
      GeometricShapeRenderer(
        shapes: [
          GeometricShape(
            type: ShapeType.angle,
            label: label,
            color: color,
            points: [p1, vertex, p2],
            arcs: arcs,
          ),
        ],
        width: width,
        height: height ?? 220,
      );

  /// Render a circle with a tangent line.
  static Widget tangentCircle({
    double radius = 1.0,
    String? label,
    Color color = Colors.cyanAccent,
    double? width,
    double? height,
  }) =>
      GeometricShapeRenderer(
        shapes: [
          GeometricShape(
            type: ShapeType.tangentCircle,
            label: label,
            color: color,
            radius: radius,
          ),
        ],
        width: width,
        height: height ?? 250,
      );

  /// Build multiple shapes in one canvas.
  static Widget multiShape({
    required List<GeometricShape> shapes,
    double? width,
    double? height,
  }) =>
      GeometricShapeRenderer(
        shapes: shapes,
        width: width,
        height: height ?? 300,
      );
}
