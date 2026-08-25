import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditableDataGrid extends StatefulWidget {
  final List<String> columnHeaders;
  final List<List<String>> initialData;
  final ValueChanged<List<List<String>>>? onDataChanged;
  final String? title;
  final bool readOnly;

  const EditableDataGrid({
    super.key,
    required this.columnHeaders,
    required this.initialData,
    this.onDataChanged,
    this.title,
    this.readOnly = false,
  });

  @override
  State<EditableDataGrid> createState() => _EditableDataGridState();
}

class _EditableDataGridState extends State<EditableDataGrid> {
  late List<List<TextEditingController>> _controllers;
  late List<List<String>> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData.map((row) => List<String>.from(row)).toList();
    _controllers = _data.map((row) => row.map((cell) => TextEditingController(text: cell)).toList()).toList();
  }

  @override
  void dispose() {
    for (final row in _controllers) {
      for (final ctrl in row) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      final newRow = List.filled(widget.columnHeaders.length, '');
      _data.add(newRow);
      _controllers.add(newRow.map((c) => TextEditingController(text: c)).toList());
    });
    _notifyChange();
  }

  void _removeRow(int index) {
    if (_data.length <= 1) return;
    setState(() {
      for (final ctrl in _controllers[index]) {
        ctrl.dispose();
      }
      _data.removeAt(index);
      _controllers.removeAt(index);
    });
    _notifyChange();
  }

  void _addColumn() {
    setState(() {
      for (int i = 0; i < _data.length; i++) {
        _data[i].add('');
        _controllers[i].add(TextEditingController());
      }
    });
    _notifyChange();
  }

  void _notifyChange() {
    final result = _controllers.map((row) => row.map((ctrl) => ctrl.text).toList()).toList();
    widget.onDataChanged?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.white12;
    final headerBg = const Color(0xFF3D5AFE).withAlpha(40);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null || !widget.readOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
              child: Row(
                children: [
                  if (widget.title != null)
                    Expanded(
                      child: Text(
                        widget.title!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (!widget.readOnly) ...[
                    _gridBtn(Icons.playlist_add, 'Add row', _addRow),
                    const SizedBox(width: 4),
                    _gridBtn(Icons.view_column_outlined, 'Add col', _addColumn),
                  ],
                ],
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              horizontalMargin: 12,
              headingRowHeight: 32,
              dataRowHeight: 36,
              headingTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              dataTextStyle: const TextStyle(color: Colors.white70, fontSize: 12),
              headingRowColor: WidgetStateProperty.all(headerBg),
              border: TableBorder(
                horizontalInside: BorderSide(color: borderColor),
                verticalInside: BorderSide(color: borderColor),
              ),
              columns: [
                ...widget.columnHeaders.map(
                  (h) => DataColumn(
                    label: Text(h, style: const TextStyle(fontSize: 11)),
                  ),
                ),
                if (!widget.readOnly) const DataColumn(label: SizedBox(width: 32)),
              ],
              rows: _data.asMap().entries.map((entry) {
                final rowIdx = entry.key;
                final row = entry.value;
                return DataRow(
                  cells: [
                    ...row.asMap().entries.map((cellEntry) {
                      final colIdx = cellEntry.key;
                      return DataCell(
                        SizedBox(
                          width: 60,
                          height: 28,
                          child: widget.readOnly
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _controllers[rowIdx][colIdx].text,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                )
                              : TextField(
                                  controller: _controllers[rowIdx][colIdx],
                                  onChanged: (_) => _notifyChange(),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[\d.\-]')),
                                  ],
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withAlpha(10),
                                  ),
                                ),
                        ),
                      );
                    }),
                    if (!widget.readOnly)
                      DataCell(
                        rowIdx > 0 || _data.length > 1
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                                padding: EdgeInsets.zero,
                                onPressed: () => _removeRow(rowIdx),
                              )
                            : const SizedBox(width: 32),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _gridBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 14, color: Colors.cyanAccent),
        ),
      ),
    );
  }
}
