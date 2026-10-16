import 'package:web/web.dart' as web;

void styleChemistryLabHost(Object element, String hostId) {
  final div = element as web.HTMLDivElement;
  div.id = hostId;
  div.style
    ..width = '100%'
    ..height = '100%'
    ..overflow = 'hidden';
}
