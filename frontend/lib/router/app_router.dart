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

class AppRouter {
  final AuthProvider authProvider;

  AppRouter(this.authProvider);

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
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        builder: (_, __, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeRedirect()),
          GoRoute(path: '/student', builder: (_, __) => const StudentDashboard()),
          GoRoute(path: '/dashboard', builder: (_, __) => const StudentDashboard()),
          GoRoute(path: '/lecturer', builder: (_, __) => const LecturerCentre()),
          GoRoute(path: '/ai-tutor', builder: (_, __) => const AiTutorScreen()),
          GoRoute(path: '/research', builder: (_, __) => const ResearchLab()),
          GoRoute(path: '/vault', builder: (_, __) => const KnowledgeVaultScreen()),
          GoRoute(path: '/assessment-studio', builder: (_, __) => const AssessmentStudio()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsDashboard()),
          GoRoute(path: '/learning-coach', builder: (_, __) => const LearningCoachScreen()),
          GoRoute(path: '/malawi-context', builder: (_, __) => const MalawiContextScreen()),
          GoRoute(path: '/knowledge-retrieval', builder: (_, __) => const KnowledgeRetrievalScreen()),
          GoRoute(path: '/examinations', builder: (_, __) => const ExaminationHall()),
          GoRoute(path: '/writing-studio', builder: (_, __) => const WritingStudio()),
          GoRoute(path: '/gamification', builder: (_, __) => const GamificationScreen()),
          GoRoute(path: '/smart-notifications', builder: (_, __) => const SmartNotificationsScreen()),
          GoRoute(path: '/search', builder: (_, __) => const GlobalSearchScreen()),
          GoRoute(path: '/offline-sync', builder: (_, __) => const OfflineSyncScreen()),
          GoRoute(path: '/classes', builder: (_, __) => const StudentDashboard()),
          GoRoute(path: '/assignments', builder: (_, __) => const StudentDashboard()),
          GoRoute(path: '/assessments', builder: (_, __) => const StudentDashboard()),
          GoRoute(path: '/grades', builder: (_, __) => const AnalyticsDashboard()),
          GoRoute(path: '/calendar', builder: (_, __) => const StudentDashboard()),
          GoRoute(path: '/notes', builder: (_, __) => const KnowledgeVaultScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/help', builder: (_, __) => const StudentDashboard()),
          GoRoute(
            path: '/smart-marking',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return SmartMarkingScreen(
                assessmentId: extra['assessmentId'] ?? 0,
                submissions: extra['submissions'] ?? [],
              );
            },
          ),
          GoRoute(
            path: '/study-plan',
            builder: (_, state) {
              final courseId = state.extra as int? ?? 1;
              return StudyPlanScreen(courseId: courseId);
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
