import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';
import 'map_library_page.dart';
import 'smartboard.dart';

const _defaultApiUrl = String.fromEnvironment(
  'MAPREADS_API_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

void main() => runApp(const MapReadsApp());

class MapReadsApp extends StatefulWidget {
  const MapReadsApp({super.key});

  @override
  State<MapReadsApp> createState() => _MapReadsAppState();
}

class _MapReadsAppState extends State<MapReadsApp> {
  late ApiClient _api;
  late String _apiUrl;
  SmartboardController? _board;
  int _page = 0;
  int _libraryRefresh = 0;
  String? _savedMapId;
  String? _lastSmartboardEvent;
  bool? _apiOnline;
  bool _darkMode = false;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _apiUrl = _defaultApiUrl;
    _api = ApiClient(_apiUrl);
    _checkApi();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _checkApi() async {
    try {
      await _api.checkHealth();
      if (mounted) setState(() => _apiOnline = true);
    } on ApiException {
      if (mounted) setState(() => _apiOnline = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade800 : null,
      ),
    );
  }

  Future<Map<String, dynamic>?> _mapSettingsDialog() async {
    final seedController = TextEditingController(text: '7');
    final formKey = GlobalKey<FormState>();
    var terrain = 'hills';
    var hills = 3;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          title: Row(
            children: [
              Icon(
                Icons.terrain_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Create a terrain map')),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose a landform and a seed to generate a repeatable Malawi study area.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: seedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Map seed',
                      helperText: 'Use the same seed to recreate this terrain.',
                      prefixIcon: Icon(Icons.tag),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => int.tryParse(value ?? '') == null
                        ? 'Enter a whole number for the map seed.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: terrain,
                    decoration: const InputDecoration(
                      labelText: 'Landform',
                      prefixIcon: Icon(Icons.landscape_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'hills',
                        child: Text('Hills and ridges'),
                      ),
                      DropdownMenuItem(
                        value: 'escarp',
                        child: Text('Escarpment'),
                      ),
                      DropdownMenuItem(value: 'uvalley', child: Text('U-valley')),
                      DropdownMenuItem(
                        value: 'mixed',
                        child: Text('Mixed relief'),
                      ),
                    ],
                    onChanged: (value) =>
                        update(() => terrain = value ?? terrain),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: hills,
                    decoration: const InputDecoration(
                      labelText: 'Mountain groups',
                      prefixIcon: Icon(Icons.filter_hdr_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: [1, 2, 3, 4, 5, 6]
                        .map(
                          (count) => DropdownMenuItem(
                            value: count,
                            child: Text('$count ${count == 1 ? 'group' : 'groups'}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => update(() => hills = value ?? hills),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final seed = int.parse(seedController.text);
                Navigator.pop(context, {
                  'seed': seed,
                  'hills': hills,
                  'terrain': terrain,
                  'complexity': 2,
                  'interval': 20,
                  'scale': 50000,
                  'view': 'v2d',
                  'verticalExaggeration': 2,
                  'layers': {
                    'roads': true,
                    'settlements': true,
                    'landCover': true,
                    'boundary': true,
                    'rivers': true,
                    'schools': true,
                    'markets': true,
                    'bridges': true,
                    'boreholes': true,
                    'woodland': true,
                    'cultivation': true,
                    'wetlands': true,
                  },
                });
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate terrain'),
            ),
          ],
        ),
      ),
    );
    seedController.dispose();
    return result;
  }

  Future<void> _generateMap() async {
    final config = await _mapSettingsDialog();
    if (config == null || _board == null) return;
    setState(() => _working = true);
    try {
      final response = await _api.generateMap(config);
      final normalized = (response['config'] as Map).cast<String, dynamic>();
      await _board!.setState({'config': normalized});
      _savedMapId = null;
      _showMessage('Map generated and validated by the MapReads API.');
    } on ApiException catch (error) {
      await _board!.setState({'config': config});
      _savedMapId = null;
      _showMessage(
        'Generated locally. API validation unavailable: ${error.message}',
      );
    } catch (error) {
      _showMessage('Could not generate the map: $error', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _saveMap() async {
    final board = _board;
    if (board == null) {
      _showMessage('The smartboard is still loading.');
      return;
    }
    final controller = TextEditingController(
      text: 'Map ${DateTime.now().toLocal().toString().substring(0, 10)}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save to map library'),
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
            child: const Text('Save map'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _working = true);
    try {
      final state = await board.getState();
      final config = (state['config'] as Map).cast<String, dynamic>();
      final annotations = (state['annotations'] as List<dynamic>?) ?? const [];
      final saved = _savedMapId == null
          ? await _api.createMap(
              name: name,
              config: config,
              annotations: annotations,
            )
          : await _api.updateMap(
              _savedMapId!,
              name: name,
              config: config,
              annotations: annotations,
            );
      _savedMapId = saved['id'] as String;
      setState(() => _libraryRefresh++);
      _showMessage('“$name” saved to the map library.');
    } on ApiException catch (error) {
      _showMessage(error.message, error: true);
    } catch (error) {
      _showMessage('Could not save this map: $error', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _exportPng() async {
    final board = _board;
    if (board == null) return;
    final mapId = _savedMapId;
    if (mapId == null) {
      _showMessage('Save this map to the library before exporting its PNG.');
      return;
    }
    setState(() => _working = true);
    try {
      final image = await board.getPng();
      final downloadUrl = await _api.createPngExport(mapId, image);
      final opened = await launchUrl(
        Uri.parse(downloadUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened)
        throw const ApiException('The PNG download could not be opened.');
      _showMessage('PNG export saved. Your browser will download the image.');
    } on ApiException catch (error) {
      _showMessage(error.message, error: true);
    } catch (error) {
      _showMessage('PNG export failed: $error', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _printPdf() async {
    try {
      await _board?.printMap();
      _showMessage(
        'Use the print dialog’s “Save as PDF” option to create teaching material.',
      );
    } catch (error) {
      _showMessage('Could not open the print dialog: $error', error: true);
    }
  }

  Future<void> _openMap(String id) async {
    setState(() => _working = true);
    try {
      final map = await _api.getMap(id);
      await _board?.setState({
        'config': map['config'],
        'annotations': map['annotations'],
      });
      _savedMapId = id;
      if (mounted) setState(() => _page = 0);
    } on ApiException catch (error) {
      _showMessage(error.message, error: true);
    } catch (error) {
      _showMessage('Could not reopen the map: $error', error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _applyApiUrl(String value) {
    final next = value.trim().replaceAll(RegExp(r'/+$'), '');
    _api.close();
    setState(() {
      _apiUrl = next;
      _api = ApiClient(next);
      _apiOnline = null;
    });
    _checkApi();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff17674f),
        brightness: _darkMode ? Brightness.dark : Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: _darkMode
          ? const Color(0xff151b19)
          : const Color(0xfff5f7f4),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0x180d3225)),
        ),
      ),
    );
    return MaterialApp(
      title: 'MapReads · MSCE Geography',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.map_outlined,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MapReads',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'MALAWI · MSCE GEOGRAPHY',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (_page == 0) ...[
              IconButton(
                tooltip: 'Generate a new map',
                onPressed: _working ? null : _generateMap,
                icon: const Icon(Icons.add_location_alt_outlined),
              ),
              IconButton(
                tooltip: 'Save map to library',
                onPressed: _working ? null : _saveMap,
                icon: const Icon(Icons.bookmark_add_outlined),
              ),
              PopupMenuButton<String>(
                tooltip: 'Export map',
                onSelected: (value) {
                  if (value == 'png') _exportPng();
                  if (value == 'print') _printPdf();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'png',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.image_outlined),
                      title: Text('Export high-resolution PNG'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'print',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.print_outlined),
                      title: Text('Print / save PDF'),
                    ),
                  ),
                ],
              ),
            ],
            _ApiStatus(online: _apiOnline, onRefresh: _checkApi),
            const SizedBox(width: 12),
            if (_working)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            return Row(
              children: [
                if (wide)
                  NavigationRail(
                    selectedIndex: _page,
                    onDestinationSelected: (index) =>
                        setState(() => _page = index),
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.edit_road_outlined),
                        selectedIcon: Icon(Icons.edit_road),
                        label: Text('Workspace'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.folder_open_outlined),
                        selectedIcon: Icon(Icons.folder_open),
                        label: Text('Map library'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.tune_outlined),
                        selectedIcon: Icon(Icons.tune),
                        label: Text('Settings'),
                      ),
                    ],
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _page,
                    children: [
                      _Workspace(
                        boardController: (controller) => _board = controller,
                        darkMode: _darkMode,
                        onEvent: (event) => setState(
                          () => _lastSmartboardEvent = event['name'] as String?,
                        ),
                      ),
                      MapLibraryPage(
                        key: ValueKey(_libraryRefresh),
                        api: _api,
                        refreshToken: _libraryRefresh,
                        onOpen: _openMap,
                      ),
                      _SettingsPage(
                        apiUrl: _apiUrl,
                        online: _apiOnline,
                        darkMode: _darkMode,
                        lastSmartboardEvent: _lastSmartboardEvent,
                        onApiUrlChanged: _applyApiUrl,
                        onThemeChanged: (value) {
                          setState(() => _darkMode = value);
                          if (_board != null) {
                            _board!.setState({
                              'theme': value ? 'dark' : 'light',
                            });
                          }
                        },
                        onRefresh: _checkApi,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: MediaQuery.sizeOf(context).width < 820
            ? NavigationBar(
                selectedIndex: _page,
                onDestinationSelected: (index) => setState(() => _page = index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.edit_road_outlined),
                    selectedIcon: Icon(Icons.edit_road),
                    label: 'Workspace',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.folder_open_outlined),
                    selectedIcon: Icon(Icons.folder_open),
                    label: 'Map library',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.tune_outlined),
                    selectedIcon: Icon(Icons.tune),
                    label: 'Settings',
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace({
    required this.boardController,
    required this.darkMode,
    required this.onEvent,
  });

  final ValueChanged<SmartboardController> boardController;
  final bool darkMode;
  final SmartboardEvent onEvent;

  @override
  Widget build(BuildContext context) =>
      SmartboardView(
        darkMode: darkMode,
        onReady: boardController,
        onEvent: onEvent,
      );
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    required this.apiUrl,
    required this.online,
    required this.darkMode,
    required this.lastSmartboardEvent,
    required this.onApiUrlChanged,
    required this.onThemeChanged,
    required this.onRefresh,
  });

  final String apiUrl;
  final bool? online;
  final bool darkMode;
  final String? lastSmartboardEvent;
  final ValueChanged<String> onApiUrlChanged;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onRefresh;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.apiUrl);
  }

  @override
  void didUpdateWidget(covariant _SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiUrl != widget.apiUrl) _urlController.text = widget.apiUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 18),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backend connection',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Configure the MapReads API independently of the rendering engine.',
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'API base URL',
                    hintText: 'http://127.0.0.1:8000',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () =>
                          widget.onApiUrlChanged(_urlController.text),
                      icon: const Icon(Icons.link),
                      label: const Text('Apply and check'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onRefresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check again'),
                    ),
                    _ApiStatus(
                      online: widget.online,
                      onRefresh: widget.onRefresh,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Build-time default: --dart-define=MAPREADS_API_URL=https://your-api.example. The value above applies for this app session.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          child: SwitchListTile(
            value: widget.darkMode,
            onChanged: widget.onThemeChanged,
            title: const Text('Dark appearance'),
            subtitle: const Text(
              'Changes the Flutter shell and smartboard theme.',
            ),
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
        ),
      ),
      const SizedBox(height: 14),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          child: ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: const Text('JavaScript bridge'),
            subtitle: Text(
              widget.lastSmartboardEvent == null
                  ? 'Waiting for smartboard events'
                  : 'Last event: ${widget.lastSmartboardEvent}',
            ),
            trailing: const Chip(label: Text('Connected surface')),
          ),
        ),
      ),
      const SizedBox(height: 14),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: const Card(
          child: ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Map persistence'),
            subtitle: Text(
              'SQLite is active for saved maps and PNG exports. PostgreSQL migration remains a future deployment decision.',
            ),
          ),
        ),
      ),
    ],
  );
}

class _ApiStatus extends StatelessWidget {
  const _ApiStatus({required this.online, required this.onRefresh});

  final bool? online;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final color = online == true
        ? Colors.green.shade700
        : online == false
        ? Colors.red.shade700
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final label = online == true
        ? 'API connected'
        : online == false
        ? 'API offline'
        : 'Checking API';
    return Tooltip(
      message: 'Check the configured FastAPI health endpoint',
      child: TextButton.icon(
        onPressed: onRefresh,
        icon: Icon(
          online == true ? Icons.cloud_done_outlined : Icons.cloud_outlined,
          color: color,
          size: 19,
        ),
        label: Text(label, style: TextStyle(color: color)),
      ),
    );
  }
}
