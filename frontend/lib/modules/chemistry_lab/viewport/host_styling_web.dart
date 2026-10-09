import 'package:web/web.dart' as web;

/// Styles the platform-view host element before Flutter attaches it.
///
/// Web-only (uses `package:web`); selected by the conditional import in
/// `lab_viewport.dart` so VM/mobile builds and tests never see `dart:js_interop`.
void styleLabHost(Object element, String hostId) {
  final div = element as web.HTMLDivElement;
  div.id = hostId;
  div.style
    ..width = '100%'
    ..height = '100%'
    ..overflow = 'hidden';
}
