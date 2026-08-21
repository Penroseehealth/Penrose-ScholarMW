import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations._();

  static const supportedLocales = [Locale('en'), Locale('ny')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      // Navigation
      'appTitle': 'Penrose ScholarMW',
      'dashboard': 'Dashboard',
      'scholarAI': 'ScholarAI',
      'myLearning': 'My Learning',
      'research': 'Research',
      'settings': 'Settings',
      'profile': 'Profile',
      'logout': 'Log Out',
      'login': 'Log In',
      'register': 'Register',

      // Home
      'goodMorning': 'Good morning',
      'goodAfternoon': 'Good afternoon',
      'goodEvening': 'Good evening',
      'welcomeBack': 'Welcome back',
      'whatsNext': "What's next on your schedule?",

      // AI Tutor
      'askScholarAI': 'Ask ScholarAI...',
      'aiTutor': 'AI Tutor',
      'studyCoach': 'Study Coach',
      'academicWriter': 'Academic Writer',
      'researchAssistant': 'Research Assistant',
      'assessmentAI': 'Assessment AI',
      'aiGenerated': 'AI-generated',
      'thinking': 'Thinking...',
      'whatToLearn': 'What would you like to learn?',
      'scholarAICompanion': 'ScholarAI is your intelligent academic companion',

      // AI Governance
      'aiDisclaimer':
          'Responses are AI-generated and may contain inaccuracies. Always verify with authoritative sources.',
      'aiAnalysis': 'AI-generated analysis',

      // STEM
      'stemIntelligence': 'STEM Intelligence',
      'knowledgeGraph': 'Knowledge Graph',
      'formulaCentre': 'Formula Centre',
      'stemLabs': 'STEM Labs',
      'stemTutor': 'STEM Tutor',
      'myMastery': 'My Mastery',
      'careerExplorer': 'Career Explorer',
      'stemAnalytics': 'STEM Analytics',
      'malawiSTEM': 'Malawi STEM',
      'revisionTools': 'Revision Tools',
      'achievements': 'Achievements',
      'studyGroups': 'Study Groups',

      // Tools
      'dataAnalysis': 'Data Analysis',
      'codingPlayground': 'Coding Playground',
      'voiceTutor': 'Voice Tutor',
      'analyticsExport': 'Analytics Export',
      'contentManager': 'Content Manager',
      'notes': 'Notes',
      'downloads': 'Downloads',

      // Data Analysis
      'dataAnalysisWorkspace': 'Data Analysis Workspace',
      'datasetCSV': 'Dataset (CSV format)',
      'askQuestionOptional': 'Ask a question about the data (optional)',
      'analyzeData': 'Analyze Data',
      'analyzing': 'Analyzing...',
      'columnStatistics': 'Column Statistics',
      'sampleData': 'Sample Data',
      'aiAnalysisLabel': 'AI Analysis',

      // Coding Playground
      'codeEditor': 'Code Editor',
      'output': 'Output',
      'runCode': 'Run code',
      'running': 'Running...',
      'clickToRun': 'Click Run to execute your code',
      'codeCopied': 'Code copied to clipboard',
      'copy': 'Copy',

      // Study Planner
      'studyPlanner': 'Study Planner',
      'todaysTasks': "Today's Study Tasks",
      'noTasksToday': 'No tasks for today',
      'generatePlan': 'Generate Plan',
      'generating': 'Generating...',
      'planOverview': 'Plan Overview',
      'dailyMinutes': 'Daily Minutes',
      'duration': 'Duration',

      // Flashcards
      'flashcards': 'Flashcards',
      'generateFlashcards': 'Generate Flashcards',
      'dueReview': 'Due for Review',

      // Common
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'retry': 'Retry',
      'loading': 'Loading...',
      'noData': 'No data available',
      'error': 'Error',
      'success': 'Success',
      'confirm': 'Confirm',
      'back': 'Back',
      'next': 'Next',
      'search': 'Search',
      'filter': 'Filter',
      'sort': 'Sort',

      // Accessibility
      'accessibilityMode': 'Accessibility',
      'highContrast': 'High Contrast',
      'largeText': 'Large Text',
      'screenReader': 'Screen Reader Optimized',
    },
    'ny': {
      // Navigation
      'appTitle': 'Penrose ScholarMW',
      'dashboard': 'Khondo',
      'scholarAI': 'ScholarAI',
      'myLearning': 'Kuphunzira Kwanga',
      'research': 'Kafufuzidwe',
      'settings': 'Zikhazikizo',
      'profile': 'Maudindo',
      'logout': 'Tulukani',
      'login': 'Lowani',
      'register': 'Lezani',

      // Home
      'goodMorning': 'Moni bwino',
      'goodAfternoon': 'Masiku',
      'goodEvening': 'Madzulo',
      'welcomeBack': 'Tilandirani',
      'whatsNext': 'Chotsatira chiyani pa ndandanda yanu?',

      // AI Tutor
      'askScholarAI': 'Funanirani ScholarAI...',
      'aiTutor': 'Wophunzitsa AI',
      'studyCoach': 'Katswiri wa Kuphunzira',
      'academicWriter': 'Wolemba za Maphunziro',
      'researchAssistant': 'Wothandiza Kafufuzidwe',
      'assessmentAI': 'AI ya Kuyesa',
      'aiGenerated': 'Yapangidwa ndi AI',
      'thinking': 'Ndi kunena...',
      'whatToLearn': 'Mukufuna kuphunzira chiyani?',
      'scholarAICompanion': 'ScholarAI ndi mnzanu wanzeru wa maphunziro',

      // AI Governance
      'aiDisclaimer':
          'Mayankho ndi owapanga ndipo angakhale osakhulupirika. Onetsetsani ndi mawu olingana.',
      'aiAnalysis': 'Kafufuzidwe kapangidwa ndi AI',

      // STEM
      'stemIntelligence': 'Nzeru za STEM',
      'knowledgeGraph': 'Grafu ya Dzina',
      'formulaCentre': 'Khosi ya Fomula',
      'stemLabs': 'Labu ya STEM',
      'stemTutor': 'Wophunzitsa STEM',
      'myMastery': 'Ulimi Wanga',
      'careerExplorer': 'Wofufuza Ntchito',
      'stemAnalytics': 'Kafufuzidwe ka STEM',
      'malawiSTEM': 'STEM ya Malawi',
      'revisionTools': 'Zida Zowerekeza',
      'achievements': 'Zopambana',
      'studyGroups': 'Gulu la Kuphunzira',

      // Tools
      'dataAnalysis': 'Kafufuzidwe wa Deta',
      'codingPlayground': 'Kuimira Kode',
      'voiceTutor': 'Wophunzitsa Mawu',
      'analyticsExport': 'Kutulutsa Kafufuzidwe',
      'contentManager': 'Woyang\'anira Zolembedwa',
      'notes': 'Zolemba',
      'downloads': 'Kutsitsa',

      // Data Analysis
      'dataAnalysisWorkspace': 'Kwokhala Kafufuzidwe wa Deta',
      'datasetCSV': 'Deta (MTundu wa CSV)',
      'askQuestionOptional': 'Funani funso pandeta (si zofunika)',
      'analyzeData': 'Fufuzani Deta',
      'analyzing': 'Kufufuza...',
      'columnStatistics': 'Maloze a Chigawo',
      'sampleData': 'Deta Yoyerekeza',
      'aiAnalysisLabel': 'Kafufuzidwe ka AI',

      // Coding Playground
      'codeEditor': 'Wolemba Kode',
      'output': 'Zotuluka',
      'runCode': 'Thamizani kode',
      'running': 'Kuyenda...',
      'clickToRun': 'Dinasani Kuthamiza kuti muchite kode',
      'codeCopied': 'Kode yajambulidwa',
      'copy': 'Jambulani',

      // Study Planner
      'studyPlanner': 'Plana ya Kuphunzira',
      'todaysTasks': 'Ntchito za Lero',
      'noTasksToday': 'Palibe ntchito lero',
      'generatePlan': 'Pangani Plana',
      'generating': 'Kupanga...',
      'planOverview': 'Kuwunika kwa Plana',
      'dailyMinutes': 'Mphindi patsiku',
      'duration': 'Nthawi',

      // Flashcards
      'flashcards': 'Mapepala',
      'generateFlashcards': 'Pangani Mapepala',
      'dueReview': 'Ndikoyenera Kuyang\'aniridwa',

      // Common
      'save': 'Sungani',
      'cancel': 'Kuletsa',
      'delete': 'Chotsani',
      'edit': 'Sinthani',
      'retry': 'Yeseraninso',
      'loading': 'Kutsekula...',
      'noData': 'Palibe deta',
      'error': 'Vuto',
      'success': 'Zapambana',
      'confirm': 'Tsimikizirani',
      'back': 'Mmbacko',
      'next': 'Chotsatira',
      'search': 'Sakani',
      'filter': 'Sankhani',
      'sort': 'Wongolani',

      // Accessibility
      'accessibilityMode': 'Kulowetsa',
      'highContrast': 'Kuunika Kwambiri',
      'largeText': 'Mawu Akulu',
      'screenReader': 'Woyenera Kowerenga',
    },
  };

  String _locale = 'en';

  String get locale => _locale;

  void setLocale(String code) {
    if (_translations.containsKey(code)) {
      _locale = code;
    }
  }

  String tr(String key) => _translations[_locale]?[key] ?? _translations['en']?[key] ?? key;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ny'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final loc = AppLocalizations._();
    loc.setLocale(locale.languageCode);
    return loc;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
