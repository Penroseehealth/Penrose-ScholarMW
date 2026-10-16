import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/widgets/math_viz/ai_visual_parser.dart';

void main() {
  group('AIVisualParser.parseFromResponse', () {
    test('parses a graph visual block', () {
      const response =
          'Here is the graph:\n<!--visual:{"type":"graph","expression":"x^2","title":"Parabola","xMin":-5,"xMax":5,"yMin":-5,"yMax":5}-->';
      final visuals = AIVisualParser.parseFromResponse(response);
      expect(visuals.length, 1);
      expect(visuals[0].type, VisualType.graph);
      expect(visuals[0].expression, 'x^2');
      expect(visuals[0].title, 'Parabola');
      expect(visuals[0].xMin, -5);
      expect(visuals[0].xMax, 5);
    });

    test('parses a bar chart visual block', () {
      const response =
          '<visual>{"type":"bar_chart","title":"Scores","labels":["Math","Science","English"],"values":[85,92,78]}</visual>';
      final visuals = AIVisualParser.parseFromResponse(response);
      expect(visuals.length, 1);
      expect(visuals[0].type, VisualType.barChart);
      expect(visuals[0].title, 'Scores');
      expect(visuals[0].labels, ['Math', 'Science', 'English']);
      expect(visuals[0].values, [85, 92, 78]);
    });

    test('parses a pie chart visual block', () {
      const response =
          '<visual>{"type":"pie_chart","title":"Distribution","labels":["A","B"],"values":[40,60]}</visual>';
      final visuals = AIVisualParser.parseFromResponse(response);
      expect(visuals.length, 1);
      expect(visuals[0].type, VisualType.pieChart);
    });

    test('parses a shape visual block', () {
      const response = '<visual>{"type":"shape","shape":"triangle","title":"Triangle ABC"}</visual>';
      final visuals = AIVisualParser.parseFromResponse(response);
      expect(visuals.length, 1);
      expect(visuals[0].type, VisualType.triangle);
      expect(visuals[0].shapeType, 'triangle');
    });

    test('parses multiple visual blocks', () {
      const response =
          'First chart:\n<visual>{"type":"bar_chart","title":"A","values":[1,2,3]}</visual>\nSecond chart:\n<!--visual:{"type":"line_chart","title":"B","values":[4,5,6]}-->';
      final visuals = AIVisualParser.parseFromResponse(response);
      expect(visuals.length, 2);
      expect(visuals[0].type, VisualType.barChart);
      expect(visuals[1].type, VisualType.lineChart);
    });

    test('returns empty list for no visuals', () {
      const response = 'This is just plain text with no visual blocks.';
      final visuals = AIVisualParser.parseFromResponse(response);
      expect(visuals, isEmpty);
    });

    test('parses histogram', () {
      const response = '<visual>{"type":"histogram","title":"Freq","values":[5,12,8,3]}</visual>';
      final visuals = AIVisualParser.parseFromResponse(response);
      expect(visuals.length, 1);
      expect(visuals[0].type, VisualType.histogram);
    });

    test('parses frequency polygon', () {
      const response = '<visual>{"type":"frequency_polygon","title":"FP","values":[3,8,15,10,5]}</visual>';
      final visuals = AIVisualParser.parseFromResponse(response);
      expect(visuals.length, 1);
      expect(visuals[0].type, VisualType.frequencyPolygon);
    });

    test('parses cumulative frequency', () {
      const response = '<visual>{"type":"cumulative_frequency","title":"CF","values":[10,25,45,70,90]}</visual>';
      final visuals = AIVisualParser.parseFromResponse(response);
      expect(visuals.length, 1);
      expect(visuals[0].type, VisualType.cumulativeFrequency);
    });
  });

  group('AIVisualParser.removeVisualBlocks', () {
    test('removes visual blocks from response', () {
      const response = 'Here is the graph:\n<!--visual:{"type":"graph","expression":"x^2"}-->\nHope that helps!';
      final clean = AIVisualParser.removeVisualBlocks(response);
      expect(clean, contains('Here is the graph:'));
      expect(clean, contains('Hope that helps!'));
      expect(clean, isNot(contains('visual:')));
    });

    test('removes multiple visual blocks', () {
      const response =
          'Chart 1:\n<visual>{"type":"bar_chart","values":[1,2]}</visual>\nMiddle text\n<!--visual:{"type":"pie_chart","values":[3,4]}-->\nEnd';
      final clean = AIVisualParser.removeVisualBlocks(response);
      expect(clean, contains('Chart 1:'));
      expect(clean, contains('Middle text'));
      expect(clean, contains('End'));
      expect(clean, isNot(contains('visual')));
    });

    test('returns original when no visuals', () {
      const response = 'No visuals here.';
      final clean = AIVisualParser.removeVisualBlocks(response);
      expect(clean, response);
    });
  });

  group('AIVisualParser.hasVisuals', () {
    test('detects visual blocks', () {
      expect(AIVisualParser.hasVisuals('<!--visual:{"type":"graph"}-->'), true);
      expect(AIVisualParser.hasVisuals('<visual>{"type":"bar_chart"}</visual>'), true);
      expect(AIVisualParser.hasVisuals('No visuals here'), false);
    });
  });

  group('AIVisualParser natural language fallback', () {
    test('parses "graph y = x^2" naturally', () {
      final result = AIVisualParser.parseFromResponse('graph y = x^2');
      expect(result.length, 1);
      expect(result[0].type, VisualType.graph);
    });

    test('parses "bar chart" naturally', () {
      final result = AIVisualParser.parseFromResponse('show a bar chart');
      expect(result.length, 1);
      expect(result[0].type, VisualType.barChart);
    });

    test('parses "pie chart" naturally', () {
      final result = AIVisualParser.parseFromResponse('create a piechart');
      expect(result.length, 1);
      expect(result[0].type, VisualType.pieChart);
    });

    test('parses "triangle" naturally', () {
      final result = AIVisualParser.parseFromResponse('draw a triangle');
      expect(result.length, 1);
      expect(result[0].type, VisualType.triangle);
    });
  });
}
