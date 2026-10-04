import 'dart:math' as math;
import 'dart:ui' show Offset;

/// A semantic geometry scene graph.
///
/// Objects are described in mathematical (unit) coordinates with the origin at
/// the right-angle vertex and the y-axis pointing up, so the picture is a
/// faithful scaled drawing of the verified numbers rather than a set of pixel
/// coordinates. Keeping the meaning on each object (role, measured value,
/// label) is what lets the board erase a construction guide without harming the
/// final geometry.
enum GeometryRole { finalGeometry, construction, guide, tangent }

enum GeometryShape { line, angle }

/// One meaningful object on the board.
class GeometryObject {
  const GeometryObject({
    required this.id,
    required this.shape,
    required this.role,
    required this.start,
    required this.end,
    this.value,
    this.label = '',
    this.unit = '',
  });

  final String id;
  final GeometryShape shape;
  final GeometryRole role;
  final Offset start;
  final Offset end;

  /// Measured quantity: a length for a line, degrees for an angle.
  final double? value;
  final String label;
  final String unit;
}

/// The complete, deterministic scene for one problem.
class GeometryScene {
  const GeometryScene({
    required this.a,
    required this.b,
    required this.c,
    required this.vertex,
    required this.tipX,
    required this.tipY,
    required this.objects,
  });

  /// Side lengths: `a` lies along the x-axis, `b` up the y-axis, `c` joins them.
  final double a;
  final double b;
  final double c;

  /// Right-angle vertex (origin), the far ends of the two legs.
  final Offset vertex;
  final Offset tipX;
  final Offset tipY;

  final List<GeometryObject> objects;

  GeometryObject? byId(String id) {
    for (final GeometryObject object in objects) {
      if (object.id == id) return object;
    }
    return null;
  }

  /// Builds the scene for a right-angled triangle from its verified sides.
  factory GeometryScene.rightTriangle({required double a, required double b, double? c}) {
    final double hyp = c ?? math.sqrt(a * a + b * b);
    const Offset vertex = Offset.zero;
    final Offset tipX = Offset(a, 0);
    final Offset tipY = Offset(0, b);
    final double guideReach = math.max(1.1, a * 0.5);
    return GeometryScene(
      a: a,
      b: b,
      c: hyp,
      vertex: vertex,
      tipX: tipX,
      tipY: tipY,
      objects: <GeometryObject>[
        GeometryObject(
          id: 'side-a',
          shape: GeometryShape.line,
          role: GeometryRole.finalGeometry,
          start: vertex,
          end: tipX,
          value: a,
          label: 'a',
        ),
        GeometryObject(
          id: 'side-b',
          shape: GeometryShape.line,
          role: GeometryRole.finalGeometry,
          start: vertex,
          end: tipY,
          value: b,
          label: 'b',
        ),
        GeometryObject(
          id: 'side-c',
          shape: GeometryShape.line,
          role: GeometryRole.finalGeometry,
          start: tipX,
          end: tipY,
          value: hyp,
          label: 'c',
        ),
        const GeometryObject(
          id: 'right-angle',
          shape: GeometryShape.angle,
          role: GeometryRole.construction,
          start: Offset.zero,
          end: Offset.zero,
          value: 90,
          label: '90\u00b0',
        ),
        GeometryObject(
          id: 'guide-base',
          shape: GeometryShape.line,
          role: GeometryRole.guide,
          start: tipX,
          end: Offset(a + guideReach, 0),
        ),
      ],
    );
  }
}
