import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const Color _bioGreen = Color(0xFF10B981);

class BiologyAITutorScreen extends StatefulWidget {
  const BiologyAITutorScreen({super.key});

  @override
  State<BiologyAITutorScreen> createState() => _BiologyAITutorScreenState();
}

class _BiologyAITutorScreenState extends State<BiologyAITutorScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;
  String _selectedMode = 'explain';
  int? _selectedTopic;
  bool _syllabusLocked = true;

  static const _modes = [
    ('explain', 'Explain', Icons.lightbulb_outline_rounded),
    ('teach', 'Teach', Icons.school_rounded),
    ('example', 'Example', Icons.work_outline_rounded),
    ('diagram', 'Diagram', Icons.image_rounded),
    ('quiz', 'Quiz', Icons.quiz_rounded),
    ('simplify', 'Simplify', Icons.child_care_rounded),
    ('deepen', 'Deepen', Icons.psychology_rounded),
    ('malawi', 'Malawi Context', Icons.flag_rounded),
  ];

  static final _topics = [
    // CE1: Research Skills (Forms 1, 2, 3)
    'Biological Skills & Laboratory Safety',
    'Biology and Technology',
    'Observation and Experimentation',
    'Communication and Data Analysis',
    'Safety and First Aid in Biology',
    // CE2: Environment (Forms 1, 3)
    'Environmental Factors and Habitats',
    'Ecosystems and Food Chains',
    'Ecological Relationships',
    'Conservation and Environmental Issues',
    'Human Impact on the Environment',
    // CE3: Plant Biology (Forms 1, 2, 3, 4)
    'Introduction to Plants',
    'Plant Cells and Organisation',
    'Plant Nutrition (Photosynthesis)',
    'Transport in Plants (Xylem & Phloem)',
    'Plant Growth and Reproduction',
    'Respiration and Translocation',
    'Transpiration and Tropisms',
    // CE4: Animal Biology (Forms 1, 3)
    'Introduction to Animals',
    'Animal Cells and Organisation',
    'Animal Nutrition and Feeding',
    'Internal Structures of Animals',
    // CE5: Human Biology (Forms 1, 2, 3, 4)
    'Human Body Systems Overview',
    'Nutrition and Diet',
    'Circulatory System and Blood',
    'Respiratory System',
    'Excretory System',
    'Nervous and Endocrine System',
    'Skeletal and Muscular System',
    'Reproductive System',
    'Immunity and Disease',
    'Homeostasis and Coordination',
    'Growth and Development',
    'Population and Human Ecology',
    'Substance Use and Abuse',
    'Deficiency Diseases and Disorders',
    'Biotechnology and Human Biology',
    // CE6: Micro-organisms (Forms 2, 4)
    'Introduction to Micro-organisms',
    'Micro-organisms in Disease',
    'Micro-organisms in Food Production',
    'Micro-organisms and Waste Management',
    // CE7: Genetics and Evolution (Forms 3, 4)
    'Cell Division (Mitosis and Meiosis)',
    'Mendelian Genetics',
    'DNA and the Genome',
    'Variation and Inheritance',
    'Evolution and Natural Selection',
    'Biotechnology and Genetic Engineering',
  ];

  static final _welcomeSuggestions = [
    'Explain the process of photosynthesis',
    'What are the types of blood cells?',
    'How does osmosis work in plant root cells?',
    'Describe the structure of the human heart',
    'What is the difference between mitosis and meiosis?',
    'How do vaccines work in the immune system?',
    'Explain Mendelian genetics with an example',
    'What is the role of micro-organisms in Malawi?',
    'How do I use a microscope safely in the lab?',
    'What are the different ecosystems in Malawi?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      'Welcome to the Biology AI Tutor! I am syllabus-locked to the Malawi MSCE Biology curriculum. Ask me anything from the Forms 1 to 4 syllabus.\n\nSelect a topic or type your question below.',
      false,
      DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage(text.trim(), true, DateTime.now()));
      _sending = true;
      _messageController.clear();
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 800));

    final topicCtx = _selectedTopic != null ? _topics[_selectedTopic!] : 'General Biology';
    final response = _generateResponse(text, topicCtx);

    setState(() {
      _messages.add(_ChatMessage(response, false, DateTime.now()));
      _sending = false;
    });
    _scrollToBottom();
  }

  String _generateResponse(String question, String topic) {
    final q = question.toLowerCase();

    if (q.contains('photosynthesis') || q.contains('light reaction')) {
      return '**Photosynthesis** is the process by which green plants make their own food using light energy.\n\n'
          '🔬 **Word Equation:**\nCarbon dioxide + Water → Glucose + Oxygen\n(under light energy, in chloroplasts)\n\n'
          '**Key Points from the MSCE Syllabus:**\n'
          '• Occurs in **chloroplasts** (contain chlorophyll)\n'
          '• **Light-dependent reactions** occur on thylakoid membranes\n'
          '• **Light-independent reactions** (Calvin cycle) occur in the stroma\n'
          '• Factors affecting rate: **light intensity, CO₂ concentration, temperature**\n\n'
          '🧪 **Practical Investigation:**\n'
          'Use aquatic plants (Elodea) in sodium bicarbonate solution under different light intensities. Count oxygen bubbles produced.\n\n'
          '🇬🇼 **Malawi Context:**\n'
          'In Malawi, photosynthesis is vital for maize and tobacco crops. Deforestation reduces photosynthetic capacity of the environment.';
    }

    if (q.contains('blood') || q.contains('circulat')) {
      return '**Human Blood & Circulatory System** — Core Element 5, Human Biology\n\n'
          '**Composition of Blood:**\n'
          '• **Plasma** — liquid carrying nutrients, hormones, waste\n'
          '• **Red blood cells** — carry oxygen (contain haemoglobin)\n'
          '• **White blood cells** — fight infection (phagocytes & lymphocytes)\n'
          '• **Platelets** — help in blood clotting\n\n'
          '**Blood Vessels:**\n'
          '• **Arteries** — carry blood AWAY from heart, thick elastic walls\n'
          '• **Veins** — carry blood TO heart, have valves\n'
          '• **Capillaries** — thin walls for exchange\n\n'
          '**Double Circulatory System:**\n'
          'Pulmonary circuit (heart ↔ lungs) + Systemic circuit (heart ↔ body)\n\n'
          '🧪 **Practical:** Blood typing using anti-A and anti-B sera.';
    }

    if (q.contains('osmosis') || q.contains('diffusion') || q.contains('transport')) {
      return '**Movement of Substances** — Core Element 3, Plant Biology\n\n'
          '**Diffusion:** Movement of particles from high to low concentration\n'
          '**Osmosis:** Diffusion of water through a partially permeable membrane\n'
          '**Active Transport:** Movement against concentration gradient using energy\n\n'
          '🔬 **Osmosis Practical:**\n'
          'Place potato cylinders in different sucrose concentrations. Measure length/weight change. Plot a graph to find isotonic point.\n\n'
          '**Key MSCE Points:**\n'
          '• Osmosis requires a **partially permeable membrane**\n'
          '• Plant cells become **turgid** (gain water) or **plasmolysed** (lose water)\n'
          '• Root hair cells absorb water by osmosis\n'
          '• Active transport moves mineral ions INTO root hairs against concentration gradient';
    }

    if (q.contains('mitosis') || q.contains('meiosis') || q.contains('cell division')) {
      return '**Cell Division** — Core Element 7, Genetics & Evolution\n\n'
          '**Mitosis** (growth & repair):\n'
          '1. Prophase — chromosomes become visible\n'
          '2. Metaphase — chromosomes line up at centre\n'
          '3. Anaphase — chromatids separate to poles\n'
          '4. Telophase — nuclear membranes reform\n'
          '→ Produces 2 identical daughter cells (2n)\n\n'
          '**Meiosis** (sexual reproduction):\n'
          '• Two divisions → 4 non-identical haploid cells (n)\n'
          '• Occurs in gonads (testes/ovaries)\n'
          '• Produces genetic variation through crossing over\n\n'
          '**Comparison:**\n'
          '| Feature | Mitosis | Meiosis |\n'
          '|---------|---------|----------|\n'
          '| Divisions | 1 | 2 |\n'
          '| Cells produced | 2 | 4 |\n'
          '| Ploidy | 2n → 2n | 2n → n |\n'
          '| Genetic variation | No | Yes |';
    }

    if (q.contains('heart') || q.contains('circulatory')) {
      return '**Structure of the Human Heart** — Human Biology\n\n'
          'The heart is a double pump with 4 chambers:\n'
          '• **Right atrium** — receives deoxygenated blood from body\n'
          '• **Right ventricle** — pumps blood to lungs\n'
          '• **Left atrium** — receives oxygenated blood from lungs\n'
          '• **Left ventricle** — pumps blood to body (thickest wall)\n\n'
          '**Valves prevent backflow:**\n'
          '• Tricuspid (right side)\n'
          '• Bicuspid/mitral (left side)\n'
          '• Semi-lunar valves (at arteries)\n\n'
          '🇬🇼 **Malawi Context:**\n'
          'Heart disease is increasing in Malawi due to changing diets. Understanding circulation helps prevent cardiovascular problems.';
    }

    if (q.contains('vaccine') || q.contains('immun') || q.contains('immune')) {
      return '**Immunity & Disease** — Core Element 5, Human Biology\n\n'
          '**Types of Immunity:**\n'
          '• **Non-specific (innate):** Skin, mucous membranes, stomach acid, phagocytes\n'
          '• **Specific (acquired):** Lymphocytes produce antibodies against specific antigens\n\n'
          '**How Vaccines Work:**\n'
          '1. Vaccine contains weakened/dead pathogen or its antigens\n'
          '2. Body produces antibodies against the antigens\n'
          '3. Memory cells remain → faster response if exposed again\n\n'
          '🇬🇼 **Malawi Context:**\n'
          '• BCG vaccine (tuberculosis) given at birth\n'
          '• Polio, measles, DPT vaccines in national immunisation programme\n'
          '• HIV/AIDS is a major challenge — damages immune system (T-helper cells)\n'
          '• Malaria prevention through mosquito nets (not vaccine-based)';
    }

    if (q.contains('genetics') || q.contains('mendel') || q.contains('punnett')) {
      return '**Mendelian Genetics** — Core Element 7, Genetics & Evolution\n\n'
          '**Key Terms:**\n'
          '• Gene — unit of heredity\n'
          '• Allele — different forms of a gene\n'
          '• Dominant — expressed when one copy present (e.g. T)\n'
          '• Recessive — only expressed when two copies present (e.g. t)\n'
          '• Genotype — genetic makeup (TT, Tt, tt)\n'
          '• Phenotype — physical appearance (Tall or Short)\n\n'
          '**Monohybrid Cross (Tall × Short):**\n'
          'Tt × Tt → TT : Tt : tt = 1 : 2 : 1\n'
          'Phenotype ratio = 3 Tall : 1 Short\n\n'
          '**Malawi Context:**\n'
          'Mendelian genetics explains inheritance patterns in crops like maize and tobacco. Used in breeding programmes for disease resistance.';
    }

    if (q.contains('ecosystem') || q.contains('ecology') || q.contains('food chain')) {
      return '**Ecosystems & Environment** — Core Element 2\n\n'
          '**Ecosystem Components:**\n'
          '• **Biotic:** Producers (plants), Consumers (herbivores, carnivores), Decomposers (fungi, bacteria)\n'
          '• **Abiotic:** Temperature, rainfall, light, soil pH, wind\n\n'
          '**Energy Flow:**\n'
          'Sun → Producer → Primary Consumer → Secondary Consumer → Tertiary Consumer\n'
          '• Only ~10% of energy transfers between trophic levels\n\n'
          '🇬🇼 **Malawi Context:**\n'
          '• Lake Malawi ecosystem — unique cichlid fish biodiversity\n'
          '• Deforestation in Shire River basin affects local climate\n'
          '• Sustainable farming practices needed for soil conservation\n'
          '• Climate change affects rainy seasons and crop yields';
    }

    return '**Question:** $question\n\n'
        '**Topic:** $topic\n\n'
        'I am the Biology AI Tutor, locked to the **Malawi MSCE Biology Syllabus** (Forms 1 to 4). Here is what I can help with:\n\n'
        '• **Explain** concepts from any of the 7 Core Elements\n'
        '• **Teach** step-by-step with examples\n'
        '• **Quiz** you on syllabus topics\n'
        '• **Simplify** complex ideas\n'
        '• **Deepen** your understanding\n\n'
        '🇬🇼 All responses are contextualised to **Malawi** where relevant.\n\n'
        'Please try asking about a specific Biology topic from the syllabus!';
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
        title: const Row(
          children: [
            Icon(Icons.science_rounded, color: _bioGreen, size: 22),
            SizedBox(width: 10),
            Text('Biology AI Tutor',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          _syllabusLockBadge(),
          const SizedBox(width: 12),
        ],
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _syllabusLockBadge() {
    return GestureDetector(
      onTap: () => setState(() => _syllabusLocked = !_syllabusLocked),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _syllabusLocked
              ? _bioGreen.withValues(alpha: 0.15)
              : Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _syllabusLocked
                ? _bioGreen.withValues(alpha: 0.3)
                : Colors.orange.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _syllabusLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: _syllabusLocked ? _bioGreen : Colors.orange,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              _syllabusLocked ? 'Syllabus Locked' : 'Free Mode',
              style: TextStyle(
                color: _syllabusLocked ? _bioGreen : Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(
          width: 280,
          child: _buildSidebar(),
        ),
        const VerticalDivider(color: Colors.white10, width: 1),
        Expanded(child: _buildChatArea()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildModeBar(),
        _buildTopicSelector(),
        Expanded(child: _buildChatArea()),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: const Color(0xFF0F1623),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Topic',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _topics.length,
              itemBuilder: (_, i) {
                final selected = _selectedTopic == i;
                return ListTile(
                  dense: true,
                  selected: selected,
                  selectedTileColor: _bioGreen.withValues(alpha: 0.1),
                  leading: Icon(
                    Icons.circle_rounded,
                    size: 8,
                    color: selected ? _bioGreen : Colors.white24,
                  ),
                  title: Text(
                    _topics[i],
                    style: TextStyle(
                      color: selected ? _bioGreen : Colors.white70,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  onTap: () => setState(() => _selectedTopic = i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBar() {
    return Container(
      height: 48,
      color: const Color(0xFF0F1623),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _modes.length,
        itemBuilder: (_, i) {
          final m = _modes[i];
          final selected = _selectedMode == m.$1;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(m.$3, size: 14, color: selected ? Colors.white : Colors.white54),
                  const SizedBox(width: 4),
                  Text(m.$2, style: TextStyle(fontSize: 12)),
                ],
              ),
              selected: selected,
              onSelected: (_) => setState(() => _selectedMode = m.$1),
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              selectedColor: _bioGreen,
              labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopicSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF0F1623),
      child: Row(
        children: [
          const Icon(Icons.bookmark_rounded, color: _bioGreen, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<int?>(
              value: _selectedTopic,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A2035),
              underline: const SizedBox(),
              hint: const Text('Select a syllabus topic',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('General Biology', style: TextStyle(color: Colors.white70)),
                ),
                ..._topics.asMap().entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    )),
              ],
              onChanged: (v) => setState(() => _selectedTopic = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty ? _buildWelcome() : _buildMessageList(),
        ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _bioGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.science_rounded, color: _bioGreen, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Biology AI Tutor',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Powered by Malawi MSCE Syllabus',
              style: TextStyle(color: _bioGreen.withValues(alpha: 0.7), fontSize: 13),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _welcomeSuggestions.take(4).map((s) {
                return ActionChip(
                  label: Text(s, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  side: BorderSide(color: _bioGreen.withValues(alpha: 0.2)),
                  onPressed: () => _sendMessage(s),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[i]);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser
              ? _bioGreen.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
          border: Border.all(
            color: isUser
                ? _bioGreen.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Row(
                children: [
                  const Icon(Icons.science_rounded, color: _bioGreen, size: 14),
                  const SizedBox(width: 6),
                  Text('Biology AI',
                      style: TextStyle(color: _bioGreen.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            if (!isUser) const SizedBox(height: 6),
            SelectableText(
              msg.text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: isUser ? 0.9 : 0.85),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: const Radius.circular(4),
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.science_rounded, color: _bioGreen, size: 14),
            const SizedBox(width: 8),
            ...List.generate(3, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: Duration(milliseconds: 300 + i * 200),
                  child: Icon(Icons.circle, size: 6, color: _bioGreen.withValues(alpha: 0.5)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF0F1623),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ask a Biology question...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _bioGreen.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _bioGreen.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _bioGreen),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: _bioGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: () => _sendMessage(_messageController.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  const _ChatMessage(this.text, this.isUser, this.time);
}
