import 'package:flutter/material.dart';

import 'api_client.dart';

class MapLibraryPage extends StatefulWidget {
  const MapLibraryPage({
    required this.api,
    required this.refreshToken,
    required this.onOpen,
    super.key,
  });

  final ApiClient api;
  final int refreshToken;
  final ValueChanged<String> onOpen;

  @override
  State<MapLibraryPage> createState() => _MapLibraryPageState();
}

class _MapLibraryPageState extends State<MapLibraryPage> {
  late Future<List<Map<String, dynamic>>> _maps;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant MapLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.api != widget.api) {
      _reload();
    }
  }

  void _reload() => _maps = widget.api.listMaps();

  Future<void> _rename(Map<String, dynamic> map) async {
    final controller = TextEditingController(
      text: map['name'] as String? ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename map'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Map name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save name'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      final fullMap = await widget.api.getMap(map['id'] as String);
      await widget.api.updateMap(
        map['id'] as String,
        name: name,
        config: (fullMap['config'] as Map).cast<String, dynamic>(),
        annotations: (fullMap['annotations'] as List<dynamic>?) ?? const [],
      );
      if (mounted) setState(_reload);
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _delete(Map<String, dynamic> map) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved map?'),
        content: Text(
          '“${map['name']}” and its saved exports will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep map'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.deleteMap(map['id'] as String);
      if (mounted) setState(_reload);
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade800),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _maps,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 36),
                    const SizedBox(height: 12),
                    const Text('Map library is unavailable'),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(_reload),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final maps = snapshot.requireData;
      if (maps.isEmpty) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 54,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  'Your map library is ready',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a map in the teaching workspace and save it here. Saved maps and annotations are stored by the MapReads API.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 1050
              ? 3
              : constraints.maxWidth > 650
              ? 2
              : 1;
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: columns == 1 ? 2.4 : 1.65,
            ),
            itemCount: maps.length,
            itemBuilder: (context, index) {
              final map = maps[index];
              final config = (map['config'] as Map).cast<String, dynamic>();
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.terrain,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              map['name'] as String? ?? 'Untitled map',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Map actions',
                            onSelected: (action) {
                              if (action == 'rename') _rename(map);
                              if (action == 'delete') _delete(map);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Seed ${config['seed']}  ·  1:${config['scale']}  ·  ${config['interval']} m contours',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Updated ${_dateLabel(map['updated_at'] as String?)}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => widget.onOpen(map['id'] as String),
                            icon: const Icon(Icons.open_in_new, size: 17),
                            label: const Text('Open'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );

  String _dateLabel(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    if (date == null) return 'date unavailable';
    return '${date.day}/${date.month}/${date.year}';
  }
}
