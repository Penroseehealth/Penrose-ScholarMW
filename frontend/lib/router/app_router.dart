import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/home/student_dashboard.dart';
import '../screens/ai_tutor/ai_tutor_screen.dart';
import '../screens/student/student_hub.dart';
import '../screens/student/knowledge_vault.dart';
import '../screens/student/study_plan.dart';
import '../screens/student/profile_screen.dart';
import '../screens/analytics/analytics_dashboard.dart';
import '../screens/student/learning_coach.dart';
import '../screens/student/malawi_context_screen.dart';
import '../screens/student/knowledge_retrieval_screen.dart';
import '../screens/lecturer/lecturer_centre.dart';
import '../screens/lecturer/assessment_studio.dart';
import '../screens/lecturer/smart_marking.dart';
import '../screens/research/research_lab.dart';
import '../screens/examinations/examination_hall.dart';
import '../screens/writing/writing_studio.dart';
import '../screens/gamification/gamification_screen.dart';
import '../screens/notifications/smart_notifications_screen.dart';
import '../screens/search/global_search_screen.dart';
import '../screens/sync/offline_sync_screen.dart';
import '../screens/stem/stem_hub.dart';
import '../screens/stem/stem_subject_screen.dart';
import '../screens/stem/stem_topic_screen.dart';
import '../screens/stem/stem_concept_screen.dart';
import '../screens/stem/stem_knowledge_graph_screen.dart';
import '../screens/stem/stem_formula_centre_screen.dart';
import '../screens/stem/stem_career_explorer_screen.dart';
import '../screens/stem/stem_lab_screen.dart';
import '../screens/stem/stem_mastery_dashboard_screen.dart';
import '../screens/stem/stem_tutor_screen.dart';
import '../screens/stem/stem_analytics_screen.dart';
import '../screens/stem/stem_malawi_screen.dart';
import '../screens/stem/stem_revision_screen.dart';
import '../screens/stem/stem_gamification_screen.dart';
import '../screens/stem/stem_groups_screen.dart';
import '../screens/stem/subject_dashboard_screen.dart';
import '../screens/stem/learning_path_screen.dart';
import '../screens/stem/mock_exam_screen.dart';
import '../screens/stem/certificates_screen.dart';
import '../screens/stem/exam_analytics_screen.dart';
import '../screens/stem/study_planner_screen.dart';
import '../screens/student/messaging_screen.dart';
import '../screens/student/chat_detail_screen.dart';
import '../screens/student/notification_settings_screen.dart';
import '../screens/stem/forum_screen.dart';
import '../screens/stem/announcements_screen.dart';
import '../screens/stem/content_cms_screen.dart';
import '../screens/stem/collaboration_chat_screen.dart';
import '../screens/stem/analytics_export_screen.dart';

class AppRouter {
  final AuthProvider authProvider;

  AppRouter(this.authProvider);

  static Widget _fadeTransition(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: child,
    );
  }

  static Widget _slideTransition(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
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

  GoRoute _route(String path, Widget Function(GoRouterState) builder) {
    return GoRoute(
      path: path,
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: builder(state),
        transitionsBuilder: _slideTransition,
      ),
    );
  }

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuth = authProvider.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const RegisterScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      ShellRoute(
        builder: (_, __, child) => HomeShell(child: child),
        routes: [
          _route('/', (_) => const HomeRedirect()),
          _route('/student', (_) => const StudentDashboard()),
          _route('/dashboard', (_) => const StudentDashboard()),
          _route('/lecturer', (_) => const LecturerCentre()),
          _route('/ai-tutor', (_) => const AiTutorScreen()),
          _route('/research', (_) => const ResearchLab()),
          _route('/vault', (_) => const KnowledgeVaultScreen()),
          _route('/assessment-studio', (_) => const AssessmentStudio()),
          _route('/profile', (_) => const ProfileScreen()),
          _route('/analytics', (_) => const AnalyticsDashboard()),
          _route('/learning-coach', (_) => const LearningCoachScreen()),
          _route('/malawi-context', (_) => const MalawiContextScreen()),
          _route('/knowledge-retrieval', (_) => const KnowledgeRetrievalScreen()),
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
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: SubjectDashboardScreen(slug: slug, title: title),
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
          GoRoute(path: '/stem-knowledge-graph', pageBuilder: (_, state) {
            final slug = state.uri.queryParameters['subject'] ?? '';
            return CustomTransitionPage<void>(
              key: state.pageKey,
              child: StemKnowledgeGraphScreen(subjectSlug: slug),
              transitionsBuilder: _slideTransition,
            );
          }),
          _route('/stem-formula-centre', (_) => const StemFormulaCentreScreen()),
          GoRoute(path: '/stem-careers', pageBuilder: (_, state) {
            final slug = state.uri.queryParameters['subject'] ?? '';
            return CustomTransitionPage<void>(
              key: state.pageKey,
              child: StemCareerExplorerScreen(subjectSlug: slug),
              transitionsBuilder: _slideTransition,
            );
          }),
          GoRoute(path: '/stem-labs', pageBuilder: (_, state) {
            final slug = state.uri.queryParameters['subject'] ?? '';
            final type = state.uri.queryParameters['type'] ?? '';
            return CustomTransitionPage<void>(
              key: state.pageKey,
              child: StemLabScreen(subjectSlug: slug, labType: type),
              transitionsBuilder: _slideTransition,
            );
          }),
          _route('/stem-mastery', (_) => const StemMasteryDashboardScreen()),
          GoRoute(path: '/stem-tutor', pageBuilder: (_, state) {
            final conceptId = int.tryParse(state.uri.queryParameters['concept'] ?? '0') ?? 0;
            return CustomTransitionPage<void>(
              key: state.pageKey,
              child: StemTutorScreen(conceptId: conceptId),
              transitionsBuilder: _slideTransition,
            );
          }),
          _route('/stem-analytics', (_) => const StemAnalyticsScreen()),
          _route('/stem-malawi', (_) => const StemMalawiScreen()),
          _route('/stem-revision', (_) => const StemRevisionScreen()),
          _route('/stem-gamification', (_) => const StemGamificationScreen()),
          _route('/stem-groups', (_) => const StemGroupsScreen()),
          _route('/mock-exam', (_) => const MockExamScreen()),
          _route('/certificates', (_) => const CertificatesScreen()),
          _route('/exam-analytics', (_) => const ExamAnalyticsScreen()),
          _route('/study-planner', (_) => const StudyPlannerScreen()),
          _route('/messages', (_) => const MessagingScreen()),
          _route('/notification-settings', (_) => const NotificationSettingsScreen()),
          _route('/forum', (_) => const ForumScreen()),
          _route('/announcements', (_) => const AnnouncementsScreen()),
          _route('/content-cms', (_) => const ContentCmsScreen()),
          _route('/analytics-export', (_) => const AnalyticsExportScreen()),
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
        ],
      ),
    ],
  );
}

class HomeRedirect extends StatelessWidget {
  const HomeRedirect({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    switch (auth.userRole) {
      case 'lecturer':
        return const LecturerCentre();
      case 'admin':
        return const LecturerCentre();
      case 'researcher':
        return const ResearchLab();
      default:
        return const StudentDashboard();
    }
  }
}
