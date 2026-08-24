import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


const Color _bioGreen = Color(0xFF10B981);

class BiologyNotebookScreen extends StatefulWidget {
  const BiologyNotebookScreen({super.key});

  @override
  State<BiologyNotebookScreen> createState() => _BiologyNotebookScreenState();
}

class _BiologyNotebookScreenState extends State<BiologyNotebookScreen> {
  int _selectedTab = 0;
  int? _selectedNote;
  final TextEditingController _noteTitleController = TextEditingController();
  final TextEditingController _noteContentController = TextEditingController();
  String _selectedTopic = 'General';
  bool _showEditor = false;

  static const _tabs = ['My Notes', 'Quick Notes', 'Templates', 'Starred'];

  static final _syllabusTopics = [
    'General',
    'Research Skills',
    'Environment & Ecosystems',
    'Plant Structure',
    'Photosynthesis',
    'Transport in Plants',
    'Transpiration & Tropisms',
    'Animal Classification',
    'Internal Structure',
    'Human Digestive System',
    'Human Circulatory System',
    'Respiratory System',
    'Excretory System',
    'Nervous & Endocrine',
    'Reproductive System',
    'Immunity & Disease',
    'Blood & Blood Groups',
    'Micro-organisms',
    'Cell Division',
    'Mendelian Genetics',
    'DNA & Genome',
    'Variations & Evolution',
    'Biotechnology',
  ];

  final List<_NotebookEntry> _notes = [
    _NotebookEntry(
      'Photosynthesis Summary',
      'Key points from photosynthesis topic:\n\n'
          '• Light-dependent reactions occur in thylakoids\n'
          '• Light-independent (Calvin cycle) in stroma\n'
          '• Chlorophyll absorbs red and blue light\n'
          '• CO₂ enters through stomata\n'
          '• Rate affected by: light, CO₂, temperature\n\n'
          '🧪 Practical: Elodea + sodium bicarbonate experiment',
      'Photosynthesis',
      DateTime.now().subtract(const Duration(days: 2)),
      false,
      true,
    ),
    _NotebookEntry(
      'Heart Structure Diagram Notes',
      '4 chambers:\n'
          '• RA → receives deoxygenated blood\n'
          '• RV → pumps to lungs\n'
          '• LA → receives oxygenated blood\n'
          '• LV → pumps to body (thickest)\n\n'
          'Valves: Tricuspid, Bicuspid, Semi-lunar',
      'Human Circulatory System',
      DateTime.now().subtract(const Duration(days: 1)),
      true,
      false,
    ),
    _NotebookEntry(
      'Mendelian Genetics Formulas',
      'Monohybrid cross: Tt × Tt\n'
          '• TT : Tt : tt = 1 : 2 : 1\n'
          '• Phenotype ratio = 3 : 1\n\n'
          'Dihybrid cross: RrYy × RrYy\n'
          '• 9 : 3 : 3 : 1 phenotype ratio\n\n'
          'Key: Dominant (T) masks recessive (t)',
      'Mendelian Genetics',
      DateTime.now(),
      false,
      false,
    ),
    _NotebookEntry(
      'Malawi Disease Prevention Notes',
      'Major diseases in Malawi:\n'
          '• Malaria — Anopheles mosquito, use treated nets\n'
          '• HIV/AIDS — damages T-helper cells\n'
          '• Cholera — contaminated water\n'
          '• Bilharzia — freshwater snails\n\n'
          'Prevention: clean water, vaccination, nets',
      'Immunity & Disease',
      DateTime.now(),
      true,
      false,
    ),
  ];

  @override
  void dispose() {
    _noteTitleController.dispose();
    _noteContentController.dispose();
    super.dispose();
  }

  void _newNote() {
    _noteTitleController.clear();
    _noteContentController.clear();
    _selectedTopic = 'General';
    setState(() {
      _selectedNote = null;
      _showEditor = true;
    });
  }

  void _openNote(int index) {
    final note = _notes[index];
    _noteTitleController.text = note.title;
    _noteContentController.text = note.content;
    _selectedTopic = note.topic;
    setState(() {
      _selectedNote = index;
      _showEditor = true;
    });
  }

  void _saveNote() {
    if (_noteTitleController.text.trim().isEmpty) return;
    setState(() {
      if (_selectedNote != null) {
        _notes[_selectedNote!] = _NotebookEntry(
          _noteTitleController.text.trim(),
          _noteContentController.text.trim(),
          _selectedTopic,
          DateTime.now(),
          _notes[_selectedNote!].starred,
          _notes[_selectedNote!].syllabusLinked,
        );
      } else {
        _notes.insert(
          0,
          _NotebookEntry(
            _noteTitleController.text.trim(),
            _noteContentController.text.trim(),
            _selectedTopic,
            DateTime.now(),
            false,
            false,
          ),
        );
      }
      _showEditor = false;
      _selectedNote = null;
    });
  }

  void _deleteNote(int index) {
    setState(() {
      _notes.removeAt(index);
      _showEditor = false;
      _selectedNote = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1623),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.go('/biology'),
        ),
        title: const Text('📓 Biology Notebook',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (_showEditor)
            TextButton.icon(
              onPressed: _saveNote,
              icon: const Icon(Icons.save_rounded, color: _bioGreen, size: 18),
              label: const Text('Save', style: TextStyle(color: _bioGreen)),
            )
          else
            IconButton(
              icon: const Icon(Icons.add_rounded, color: _bioGreen),
              onPressed: _newNote,
            ),
        ],
      ),
      body: _showEditor
          ? _buildEditor()
          : isDesktop
              ? _buildDesktopLayout()
              : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(
          width: 260,
          child: _buildSidebar(),
        ),
        const VerticalDivider(color: Colors.white10, width: 1),
        Expanded(child: _buildNoteList()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildTabBar(),
        Expanded(
          child: _selectedNote != null && _showEditor
              ? _buildEditor()
              : _buildNoteList(),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 44,
      color: const Color(0xFF0F1623),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _tabs.length,
        itemBuilder: (_, i) {
          final selected = _selectedTab == i;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: ChoiceChip(
              label: Text(_tabs[i], style: const TextStyle(fontSize: 12)),
              selected: selected,
              onSelected: (_) => setState(() => _selectedTab = i),
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              selectedColor: _bioGreen,
              labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: const Color(0xFF0F1623),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('SYLLABUS TOPICS',
                style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _syllabusTopics.length,
              itemBuilder: (_, i) {
                final selected = _selectedTopic == _syllabusTopics[i];
                return ListTile(
                  dense: true,
                  selected: selected,
                  selectedTileColor: _bioGreen.withValues(alpha: 0.1),
                  leading: Icon(
                    selected ? Icons.bookmark_rounded : Icons.circle,
                    size: selected ? 16 : 6,
                    color: selected ? _bioGreen : Colors.white24,
                  ),
                  title: Text(
                    _syllabusTopics[i],
                    style: TextStyle(
                      color: selected ? _bioGreen : Colors.white60,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedTopic = _syllabusTopics[i];
                      _showEditor = false;
                      _selectedNote = null;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteList() {
    List<_NotebookEntry> filtered;
    switch (_selectedTab) {
      case 1:
        filtered = _notes.where((n) => n.content.length < 200).toList();
        break;
      case 3:
        filtered = _notes.where((n) => n.starred).toList();
        break;
      default:
        filtered = _notes.where((n) => _selectedTopic == 'General' || n.topic == _selectedTopic).toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_add_rounded,
                size: 48, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            Text('No notes yet',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _newNote,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create First Note'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _bioGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final note = filtered[i];
        final globalIndex = _notes.indexOf(note);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openNote(globalIndex),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(note.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (note.syllabusLinked)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _bioGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Syllabus',
                              style: TextStyle(color: _bioGreen, fontSize: 10)),
                        ),
                      IconButton(
                        icon: Icon(
                          note.starred ? Icons.star_rounded : Icons.star_border_rounded,
                          color: note.starred ? Colors.amber : Colors.white24,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _notes[globalIndex] = _NotebookEntry(
                              note.title,
                              note.content,
                              note.topic,
                              note.date,
                              !note.starred,
                              note.syllabusLinked,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(note.topic,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${note.date.day}/${note.date.month}/${note.date.year}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedNote != null)
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() {
                    _showEditor = false;
                    _selectedNote = null;
                  }),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white54),
                  label: const Text('Back', style: TextStyle(color: Colors.white54)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  onPressed: () => _deleteNote(_selectedNote!),
                ),
              ],
            ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedTopic,
            isExpanded: true,
            dropdownColor: const Color(0xFF1A2035),
            underline: const SizedBox(),
            items: _syllabusTopics.map((t) {
              return DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white70)));
            }).toList(),
            onChanged: (v) => setState(() => _selectedTopic = v ?? 'General'),
            icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteTitleController,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Note title...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _noteContentController,
              maxLines: null,
              expands: true,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 14, height: 1.6),
              decoration: InputDecoration(
                hintText: 'Start writing your notes here...\n\nUse this space for:\n• Lecture summaries\n• Diagram annotations\n• Revision points\n• Practical observations',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotebookEntry {
  final String title;
  final String content;
  final String topic;
  final DateTime date;
  final bool starred;
  final bool syllabusLinked;

  const _NotebookEntry(this.title, this.content, this.topic, this.date, this.starred, this.syllabusLinked);
}

