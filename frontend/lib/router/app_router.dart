import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/constants/api_constants.dart';
import '../core/networking/api_client.dart';
import '../features/audio_input/vtc/voice_training_center_page.dart';
import '../features/msce_papers/msce_papers_page.dart';
import '../modules/chemistry_lab/screens/chemistry_lab_screen.dart';
import '../modules/mathsdrill/screens/mathsdrill_progress_screen.dart';
import '../modules/mathsdrill/screens/mathsdrill_screen.dart';
import '../providers/auth_provider.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_syllabus_screen.dart';
import '../screens/agriculture/agriculture_ai_tutor.dart';
import '../screens/agriculture/agriculture_dashboard.dart';
import '../screens/agriculture/agriculture_practical_hub.dart';
import '../screens/ai_tutor/ai_tutor_screen.dart';
import '../screens/ai_tutor/ai_tutor_shell.dart';
import '../screens/analytics/analytics_dashboard.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/biology/biology_ai_tutor.dart';
import '../screens/biology/biology_analytics.dart';
import '../screens/biology/biology_dashboard.dart';
import '../screens/biology/biology_mock_exam.dart';
import '../screens/biology/biology_notebook.dart';
import '../screens/biology/biology_past_papers.dart';
import '../screens/biology/biology_practical_hub.dart';
import '../screens/biology/biology_practical_studio_screen.dart';
import '../screens/biology/biology_practice_centre.dart';
import '../screens/biology/biology_real_lab_screen.dart';
import '../screens/biology/biology_syllabus.dart';
import '../screens/biology/biology_topics.dart';
import '../screens/biology/biology_virtual_lab.dart';
import '../screens/biology/biology_visualization_screen.dart';
import '../screens/biology/neuron/neuron_communication_screen.dart';
import '../screens/chemistry/chemistry_syllabus_screen.dart';
import '../screens/physics/physics_syllabus_screen.dart';
import '../screens/stem/stem_syllabus_screen.dart';
import '../screens/data_analysis/coding_playground_screen.dart';
import '../screens/data_analysis/data_analysis_screen.dart';
import '../screens/examinations/examination_hall.dart';
import '../screens/gamification/gamification_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/home/student_dashboard.dart';
import '../screens/languages/chinese_character_lab.dart';
import '../screens/languages/chinese_hub_dashboard.dart';
import '../screens/languages/chinese_pinyin_lab.dart';
import '../screens/languages/chinese_placement_test.dart';
import '../screens/languages/chinese_radical_lab.dart';
import '../screens/languages/chinese_sentence_builder.dart';
import '../screens/languages/chinese_srs_review.dart';
import '../screens/languages/chinese_tone_lab.dart';
import '../screens/languages/language_ai_tutor.dart';
import '../screens/languages/language_assessment.dart';
import '../screens/languages/language_conversation.dart';
import '../screens/languages/language_culture.dart';
import '../screens/languages/language_dashboard.dart';
import '../screens/languages/language_grammar.dart';
import '../screens/languages/language_learning_path.dart';
import '../screens/languages/language_level_detail.dart';
import '../screens/languages/language_levels.dart';
import '../screens/languages/language_listening.dart';
import '../screens/languages/language_notebook.dart';
import '../screens/languages/language_offline.dart';
import '../screens/languages/language_practice.dart';
import '../screens/languages/language_progress.dart';
import '../screens/languages/language_pronunciation.dart';
import '../screens/languages/language_reading.dart';
import '../screens/languages/language_revision.dart';
import '../screens/languages/language_settings.dart';
import '../screens/languages/language_speaking.dart';
import '../screens/languages/language_vocabulary.dart';
import '../screens/languages/language_writing.dart';
import '../screens/languages/languages_hub.dart';
import '../screens/lecturer/assessment_studio.dart';
import '../screens/lecturer/examination_builder_screen.dart';
import '../screens/lecturer/lecture_presentation_builder_screen.dart';
import '../screens/lecturer/lecturer_centre.dart';
import '../screens/lecturer/smart_marking.dart';
import '../screens/mathematics/math_syllabus_screen.dart';
import '../screens/mathematics/math_tutor_screen.dart';
import '../screens/notifications/smart_notifications_screen.dart';
import '../screens/research/research_lab.dart';
import '../screens/search/global_search_screen.dart';
import '../screens/stem/analytics_export_screen.dart';
import '../screens/stem/announcements_screen.dart';
import '../screens/stem/certificates_screen.dart';
import '../screens/stem/collaboration_chat_screen.dart';
import '../screens/stem/content_cms_screen.dart';
import '../screens/stem/exam_analytics_screen.dart';
import '../screens/stem/forum_screen.dart';
import '../screens/stem/learning_path_screen.dart';
import '../screens/stem/mock_exam_screen.dart';
import '../screens/stem/stem_analytics_screen.dart';
import '../screens/stem/stem_career_explorer_screen.dart';
import '../screens/stem/stem_concept_screen.dart';
import '../screens/stem/stem_formula_centre_screen.dart';
import '../screens/stem/stem_gamification_screen.dart';
import '../screens/stem/stem_groups_screen.dart';
import '../screens/stem/stem_hub.dart';
import '../screens/stem/stem_knowledge_graph_screen.dart';
import '../screens/stem/stem_lab_screen.dart';
import '../screens/stem/stem_malawi_screen.dart';
import '../screens/stem/stem_mastery_dashboard_screen.dart';
import '../screens/stem/stem_revision_screen.dart';
import '../screens/stem/stem_subject_screen.dart';
import '../screens/stem/stem_topic_screen.dart';
import '../screens/stem/stem_tutor_screen.dart';
import '../screens/stem/study_planner_screen.dart';
import '../screens/stem/subject_dashboard_screen.dart';
import '../screens/student/chat_detail_screen.dart';
import '../screens/student/knowledge_retrieval_screen.dart';
import '../screens/student/knowledge_vault.dart';
import '../screens/student/learning_coach.dart';
import '../screens/student/ocr_scan_screen.dart';
import '../screens/student/malawi_context_screen.dart';
import '../screens/student/messaging_screen.dart';
import '../screens/student/notification_settings_screen.dart';
import '../screens/student/profile_screen.dart';
import '../screens/student/study_plan.dart';
import '../screens/sync/offline_sync_screen.dart';
import '../screens/writing/writing_studio.dart';
import '../services/api_service.dart';

class AppRouter {
  final AuthProvider authProvider;

  AppRouter(this.authProvider);

  /// Shared client for the Voice Training Center dashboards. The session
  /// token is resolved from secure storage on the first request.
  static final ApiClient _voiceApiClient = ApiClient(baseUrl: apiBaseUrl)
    ..tokenProvider = () => ApiService().accessToken;

  static Widget _fadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );

  static Widget _slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final tween = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic));
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    return SlideTransition(
      position: animation.drive(tween),
      child: FadeTransition(opacity: fade, child: child),
    );
  }

  /// Wraps routed content so every screen's text is selectable and copyable.
  ///
  /// Must sit below the app's `Overlay` (i.e. inside the router, not in
  /// `MaterialApp.builder`) or the selection toolbar has nowhere to render.
  static Widget _selectable(Widget child) => SelectionArea(child: child);

  GoRoute _route(String path, Widget Function(GoRouterState) builder) => GoRoute(
        path: path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: _selectable(builder(state)),
          transitionsBuilder: _slideTransition,
        ),
      );

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuth = authProvider.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isAuth && !isAuthRoute) {
        return Uri(path: '/login', queryParameters: {'redirect': state.uri.toString()}).toString();
      }
      if (isAuth && isAuthRoute) {
        final redirect = state.uri.queryParameters['redirect'];
        if (redirect != null && redirect.startsWith('/') && !redirect.startsWith('//')) {
          return redirect;
        }
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: _selectable(const LoginScreen()),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: _selectable(const RegisterScreen()),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      _route('/lecturer', (_) => const LecturerCentre()),
      _route('/lecturer/presentation-builder', (_) => const LecturePresentationBuilderScreen()),
      _route('/lecturer/examination-builder', (_) => const ExaminationBuilderScreen()),
      _route('/bio-real-lab', (state) => BiologyRealLabScreen(experimentId: state.uri.queryParameters['experiment'])),
      // MathDrill runs full-screen: registered OUTSIDE HomeShell so the main
      // navigation rail is not reserved while the workspace is open (it returns
      // automatically for every other route).
      _route('/mathsdrill', (_) => const MathsdrillScreen()),
      _route('/mathsdrill/progress', (_) => const MathsdrillProgressScreen()),
      ShellRoute(
        builder: (_, __, child) => _selectable(HomeShell(child: child)),
        routes: [
          _route('/', (_) => const HomeRedirect()),
          _route('/student', (_) => const StudentDashboard()),
          _route('/dashboard', (_) => const StudentDashboard()),
          _route('/research', (_) => const ResearchLab()),
          _route('/msce-papers', (_) => const MscePapersPage()),
          _route('/vault', (_) => const KnowledgeVaultScreen()),
          _route('/ocr-scan', (_) => const OcrScanScreen()),
          _route('/assessment-studio', (_) => const AssessmentStudio()),
          _route('/profile', (_) => const ProfileScreen()),
          _route('/analytics', (_) => const AnalyticsDashboard()),
          _route('/learning-coach', (_) => const LearningCoachScreen()),
          _route('/malawi-context', (_) => const MalawiContextScreen()),
          _route('/knowledge-retrieval', (_) => const KnowledgeRetrievalScreen()),
          _route('/voice-training-center', (_) => VoiceTrainingCenterPage(apiClient: _voiceApiClient)),
          _route('/examinations', (_) => const ExaminationHall()),
          _route('/writing-studio', (_) => const WritingStudio()),
          _route('/gamification', (_) => const GamificationScreen()),
          _route('/smart-notifications', (_) => const SmartNotificationsScreen()),
          _route('/search', (_) => const GlobalSearchScreen()),
          _route('/offline-sync', (_) => const OfflineSyncScreen()),
          _route('/stem', (_) => const StemHub()),
          GoRoute(
            path: '/stem-subject/:slug',
            pageBuilder: (_, state) {
              final slug = state.pathParameters['slug'] ?? 'mathematics';
              final title = state.uri.queryParameters['title'] ?? '';
              final widget = slug == 'biology'
                  ? const BiologyDashboard()
                  : slug == 'agriculture'
                      ? const AgricultureDashboard()
                      : SubjectDashboardScreen(slug: slug, title: title);
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: widget,
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: '/learning-path/:slug',
            pageBuilder: (_, state) {
              final slug = state.pathParameters['slug'] ?? 'mathematics';
              final title = state.uri.queryParameters['title'] ?? '';
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: LearningPathScreen(slug: slug, title: title),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: '/language/:slug/pinyin-lab',
            pageBuilder: (conf, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const ChinesePinyinLab(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/tone-lab',
            pageBuilder: (conf, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const ChineseToneLab(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/character-lab',
            pageBuilder: (conf, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const ChineseCharacterLab(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/radical-lab',
            pageBuilder: (conf, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const ChineseRadicalLab(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/sentence-builder',
            pageBuilder: (conf, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const ChineseSentenceBuilder(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/placement-test',
            pageBuilder: (conf, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const ChinesePlacementTest(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/srs-review',
            pageBuilder: (conf, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const ChineseSrsReview(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/stem/:slug',
            pageBuilder: (_, state) {
              final slug = state.pathParameters['slug'] ?? 'mathematics';
              final title = state.uri.queryParameters['title'] ?? '';
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: StemSubjectScreen(slug: slug, title: title),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: '/stem-topic/:id',
            pageBuilder: (_, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
              final title = state.uri.queryParameters['title'] ?? '';
              final difficulty = state.uri.queryParameters['difficulty'] ?? 'intermediate';
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: StemTopicScreen(topicId: id, title: title, difficulty: difficulty),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: '/stem-concept/:id',
            pageBuilder: (_, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
              final title = state.uri.queryParameters['title'] ?? '';
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: StemConceptScreen(conceptId: id, title: title),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: '/stem-knowledge-graph',
            pageBuilder: (_, state) {
              final slug = state.uri.queryParameters['subject'] ?? '';
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: StemKnowledgeGraphScreen(subjectSlug: slug),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          _route('/stem-formula-centre', (_) => const StemFormulaCentreScreen()),
          GoRoute(
            path: '/stem-careers',
            pageBuilder: (_, state) {
              final slug = state.uri.queryParameters['subject'] ?? '';
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: StemCareerExplorerScreen(subjectSlug: slug),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: '/stem-labs',
            pageBuilder: (_, state) {
              final slug = state.uri.queryParameters['subject'] ?? '';
              final type = state.uri.queryParameters['type'] ?? '';
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: StemLabScreen(subjectSlug: slug, labType: type),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          _route('/stem-mastery', (_) => const StemMasteryDashboardScreen()),
          GoRoute(
            path: '/stem-tutor',
            pageBuilder: (_, state) {
              final conceptId = int.tryParse(state.uri.queryParameters['concept'] ?? '0') ?? 0;
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: StemTutorScreen(conceptId: conceptId),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          _route('/stem-analytics', (_) => const StemAnalyticsScreen()),
          _route('/stem-malawi', (_) => const StemMalawiScreen()),
          _route('/stem-revision', (_) => const StemRevisionScreen()),
          _route('/stem-gamification', (_) => const StemGamificationScreen()),
          _route('/stem-groups', (_) => const StemGroupsScreen()),
          _route('/mock-exam', (_) => const MockExamScreen()),
          _route('/math-tutor', (_) => const MathTutorScreen()),
          _route('/certificates', (_) => const CertificatesScreen()),
          _route('/exam-analytics', (_) => const ExamAnalyticsScreen()),
          _route('/study-planner', (_) => const StudyPlannerScreen()),
          _route('/messages', (_) => const MessagingScreen()),
          _route('/notification-settings', (_) => const NotificationSettingsScreen()),
          _route('/forum', (_) => const ForumScreen()),
          _route('/announcements', (_) => const AnnouncementsScreen()),
          _route('/content-cms', (_) => const ContentCmsScreen()),
          _route('/analytics-export', (_) => const AnalyticsExportScreen()),
          _route('/data-analysis', (_) => const DataAnalysisScreen()),
          _route('/coding-playground', (_) => const CodingPlaygroundScreen()),
          _route('/admin', (_) => const AdminDashboardScreen()),
          _route('/admin/syllabus', (_) => const AdminSyllabusScreen()),
          _route('/math-syllabus', (_) => const MathSyllabusScreen()),
          _route('/chem-syllabus', (_) => const ChemistrySyllabusScreen()),
          _route('/chem-lab', (_) => const ChemistryLabScreen()),
          _route('/phys-syllabus', (_) => const PhysicsSyllabusScreen()),
          GoRoute(
            path: '/stem-syllabus/:slug',
            pageBuilder: (_, state) {
              final slug = state.pathParameters['slug'] ?? '';
              final title = state.uri.queryParameters['title'] ?? '';
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: StemSyllabusScreen(slug: slug, title: title),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: '/collab-chat/:id',
            pageBuilder: (_, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
              final name = state.uri.queryParameters['name'] ?? (state.extra as String? ?? 'Chat');
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: CollaborationChatScreen(groupId: id, groupName: name),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: '/messages/chat/:id',
            pageBuilder: (_, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
              final name = state.uri.queryParameters['name'] ?? (state.extra as String? ?? 'Chat');
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: ChatDetailScreen(conversationId: id, otherUserName: name),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          _route('/classes', (_) => const StudentDashboard()),
          _route('/assignments', (_) => const StudentDashboard()),
          _route('/assessments', (_) => const StudentDashboard()),
          _route('/grades', (_) => const AnalyticsDashboard()),
          _route('/calendar', (_) => const StudentDashboard()),
          _route('/notes', (_) => const KnowledgeVaultScreen()),
          _route('/settings', (_) => const ProfileScreen()),
          _route('/help', (_) => const StudentDashboard()),
          GoRoute(
            path: '/smart-marking',
            pageBuilder: (_, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: SmartMarkingScreen(
                  assessmentId: extra['assessmentId'] ?? 0,
                  submissions: extra['submissions'] ?? [],
                ),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: '/study-plan',
            pageBuilder: (_, state) {
              final courseId = state.extra as int? ?? 1;
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: StudyPlanScreen(courseId: courseId),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          _route('/bio-topics', (_) => const BiologyTopicsScreen()),
          _route('/bio-virtual-lab', (_) => const BiologyVirtualLabScreen()),
          _route('/bio-diagrams', (_) => const BiologyVisualizationScreen()),
          _route('/bio-neuron', (_) => const NeuronCommunicationScreen()),
          _route('/bio-practicals', (_) => const BiologyPracticalHubScreen()),
          _route('/bio-practicals/studio', (_) => const BiologyPracticalStudioScreen()),
          _route('/bio-practice', (_) => const BiologyPracticeCentreScreen()),
          _route('/bio-past-papers', (_) => const BiologyPastPapersScreen()),
          _route('/bio-mock-exam', (_) => const BiologyMockExamScreen()),
          _route('/bio-syllabus', (_) => const BiologySyllabusScreen()),
          _route('/bio-ai-tutor', (_) => const BiologyAITutorScreen()),
          _route('/bio-notebook', (_) => const BiologyNotebookScreen()),
          _route('/bio-analytics', (_) => const BiologyAnalyticsScreen()),
          _route('/agri-topics', (_) => const StemSyllabusScreen(slug: 'agriculture', title: 'Agriculture')),
          _route('/agri-syllabus', (_) => const StemSyllabusScreen(slug: 'agriculture', title: 'Agriculture')),
          _route('/agri-ai-tutor', (_) => const AgricultureAiTutorScreen()),
          _route('/agri-practicals', (_) => const AgriculturePracticalHub()),
          _route('/agri-visuals', (_) => const StemSyllabusScreen(slug: 'agriculture', title: 'Agriculture')),
          _route('/agri-practice', (_) => const StemSyllabusScreen(slug: 'agriculture', title: 'Agriculture')),
          _route('/agri-assessments', (_) => const StemSyllabusScreen(slug: 'agriculture', title: 'Agriculture')),
          _route('/agri-revision', (_) => const StemSyllabusScreen(slug: 'agriculture', title: 'Agriculture')),
          _route('/agri-notebook', (_) => const StemSyllabusScreen(slug: 'agriculture', title: 'Agriculture')),
          _route('/languages', (_) => const LanguagesHub()),
          GoRoute(
            path: '/language/:slug',
            pageBuilder: (_, state) {
              final slug = state.pathParameters['slug'] ?? 'english';
              final Widget widget = slug == 'chinese' ? ChineseHubDashboard(slug: slug) : LanguageDashboard(slug: slug);
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: widget,
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: '/language/:slug/vocabulary',
            pageBuilder: (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const LanguageVocabulary(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/grammar',
            pageBuilder: (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const LanguageGrammar(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/listening',
            pageBuilder: (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const LanguageListening(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/speaking',
            pageBuilder: (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const LanguageSpeaking(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/reading',
            pageBuilder: (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const LanguageReading(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/writing',
            pageBuilder: (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const LanguageWriting(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/notebook',
            pageBuilder: (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const LanguageNotebook(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/conversation',
            pageBuilder: (_, state) {
              final slug = state.pathParameters['slug'] ?? 'english';
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: LanguageConversationScreen(slug: slug),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: '/language/:slug/ai-tutor',
            pageBuilder: (_, state) {
              final slug = state.pathParameters['slug'] ?? 'english';
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: LanguageAITutorScreen(slug: slug),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: '/language/:slug/practice',
            pageBuilder: (_, state) {
              final slug = state.pathParameters['slug'] ?? 'english';
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: LanguagePracticeScreen(slug: slug),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: '/language/:slug/assessment',
            pageBuilder: (_, state) {
              final slug = state.pathParameters['slug'] ?? 'english';
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: LanguageAssessmentScreen(slug: slug),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: '/language/:slug/progress',
            pageBuilder: (_, state) {
              final slug = state.pathParameters['slug'] ?? 'english';
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: LanguageProgressScreen(slug: slug),
                transitionsBuilder: _slideTransition,
              );
            },
          ),
          GoRoute(
            path: '/language/:slug/levels',
            pageBuilder: (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const LanguageLevels(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/levels/:levelSlug',
            pageBuilder: (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const LanguageLevelDetail(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/path',
            pageBuilder: (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const LanguageLearningPath(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/pronunciation',
            pageBuilder: (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const LanguagePronunciation(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/revision',
            pageBuilder: (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const LanguageRevision(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/culture',
            pageBuilder: (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const LanguageCulture(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/offline',
            pageBuilder: (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const LanguageOffline(),
              transitionsBuilder: _slideTransition,
            ),
          ),
          GoRoute(
            path: '/language/:slug/settings',
            pageBuilder: (_, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const LanguageSettings(),
              transitionsBuilder: _slideTransition,
            ),
          ),
        ],
      ),
      ShellRoute(
        builder: (_, __, child) => _selectable(AiTutorShell(child: child)),
        routes: [_route('/ai-tutor', (_) => const AiTutorScreen())],
      ),
    ],
  );
}

class HomeRedirect extends StatelessWidget {
  const HomeRedirect({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      switch (auth.userRole) {
        case 'lecturer':
        case 'admin':
          context.go('/lecturer');
        case 'researcher':
          context.go('/research');
        default:
          context.go('/student');
      }
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
