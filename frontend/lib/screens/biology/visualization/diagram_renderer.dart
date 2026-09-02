import '../../../models/biology_visualization.dart';
import 'cell_diagram_renderer.dart';
import 'process_diagram_renderer.dart';

/// Facade that dispatches a structured [BiologySpec] to the correct
/// deterministic renderer based on `spec.kind`.
///
/// * `cell`    → [CellDiagramRenderer]
/// * `process` → [ProcessDiagramRenderer]
///
/// This is the single entry point the UI uses so the rendering architecture
/// stays AI-decides-WHAT / renderer-decides-HOW and new diagram families can be
/// added without touching every call site.
class DiagramRenderer {
  static String render(BiologySpec spec) {
    switch (spec.kind) {
      case 'process':
        return ProcessDiagramRenderer.render(spec);
      case 'cell':
      default:
        return CellDiagramRenderer.render(spec);
    }
  }
}
