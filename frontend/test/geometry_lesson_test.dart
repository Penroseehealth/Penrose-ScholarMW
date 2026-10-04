import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/widgets/math_tutor/geometry_lesson.dart';
import 'package:penrose_scholar/widgets/math_tutor/geometry_scene.dart';

/// The scene graph must describe the triangle in true proportions so the board
/// can draw comparative side lengths from a single scale factor.
void _testSceneProportions() {
  test('sides are stored at their verified lengths in proportional unit space', () {
    final scene = GeometryScene.rightTriangle(a: 3, b: 4);

    expect(scene.a, 3);
    expect(scene.b, 4);
    expect(scene.c, closeTo(5, 1e-9));
    expect(scene.tipX.dx, 3);
    expect(scene.tipX.dy, 0);
    expect(scene.tipY.dx, 0);
    expect(scene.tipY.dy, 4);

    final legA = (scene.tipX - scene.vertex).distance;
    final legB = (scene.tipY - scene.vertex).distance;
    final hyp = (scene.tipY - scene.tipX).distance;

    expect(legA, closeTo(3, 1e-9));
    expect(legB, closeTo(4, 1e-9));
    expect(hyp, closeTo(5, 1e-9));

    // Comparative lengths: the ratio of the drawn sides equals the ratio of
    // the real lengths, so 3-4-5 and 6-8-10 look identical in shape.
    final small = GeometryScene.rightTriangle(a: 3, b: 4);
    final large = GeometryScene.rightTriangle(a: 6, b: 8);
    expect(large.a / small.a, closeTo(large.b / small.b, 1e-9));
    expect((large.tipY - large.tipX).distance / hyp, closeTo(2, 1e-9));
  });

  test('objects carry their semantic role and measured value', () {
    final scene = GeometryScene.rightTriangle(a: 3, b: 4);
    expect(scene.byId('side-c')!.role, GeometryRole.finalGeometry);
    expect(scene.byId('side-c')!.value, closeTo(5, 1e-9));
    expect(scene.byId('guide-base')!.role, GeometryRole.guide);
    expect(scene.byId('right-angle')!.shape, GeometryShape.angle);
    expect(scene.byId('right-angle')!.value, 90);
  });
}

/// The lesson must follow a real construction order and map step progress onto
/// the beats deterministically.
void _testLessonSequence() {
  final lesson = GeometryLesson.rightTriangle(GeometryScene.rightTriangle(a: 3, b: 4));

  test('the construction follows ruler, protractor, pencil, eraser order', () {
    expect(lesson.length, 7);
    expect(lesson.beatAt(0).instrument, MathInstrument.ruler);
    expect(lesson.beatAt(1).instrument, MathInstrument.pencil);
    expect(lesson.beatAt(1).draws, 'side-a');
    expect(lesson.beatAt(2).instrument, MathInstrument.protractor);
    expect(lesson.beatAt(2).draws, 'right-angle');
    expect(lesson.beatAt(3).draws, 'side-b');
    expect(lesson.beatAt(4).draws, 'side-c');
    expect(lesson.beatAt(5).instrument, MathInstrument.eraser);
    expect(lesson.beatAt(6).instrument, MathInstrument.none);
    expect(lesson.eraseGuideBeat, 5);
  });

  test('steps map onto beats from the first to the last without gaps', () {
    expect(lesson.beatIndexFor(0, 9), 0);
    expect(lesson.beatIndexFor(8, 9), 6);
    var previous = -1;
    for (var step = 0; step < 9; step++) {
      final beat = lesson.beatIndexFor(step, 9);
      expect(beat, greaterThanOrEqualTo(previous));
      previous = beat;
    }
    expect(lesson.drawBeatOf('side-b'), 3);
    expect(lesson.drawBeatOf('guide-base'), isNull);
  });
}

void main() {
  _testSceneProportions();
  _testLessonSequence();
}
