import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/auth/profile_setup_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/assessment/assessment_overview_screen.dart';
import '../screens/assessment/mmse_test_screen.dart';
import '../screens/assessment/voice/voice_check_view.dart';
import '../screens/assessment/voice/voice_check_viewmodel.dart';
import '../screens/assessment/cookie_theft_screen.dart';
import '../screens/assessment/tug_test_screen.dart';
import '../screens/assessment/results_screen.dart';
import '../screens/medications/add_medication.dart';
import '../screens/medications/view_medications.dart';
import '../screens/consultation/consultation_screen.dart';
import '../screens/voice_assistant/voice_assistant_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/assessment/voice/results_view.dart';
import '../screens/assessment/voice/processing_view.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/assessment',
        builder: (context, state) => const AssessmentOverviewScreen(),
      ),
      GoRoute(
        path: '/assessment/mmse',
        builder: (context, state) => const MmseTestScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ChangeNotifierProvider(
          create: (_) => VoiceCheckViewModel(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/assessment/voice-analysis',
            builder: (context, state) => const VoiceCheckView(),
          ),
          GoRoute(
            path: '/assessment/voice-processing',
            builder: (context, state) => const ProcessingView(),
          ),
          GoRoute(
            path: '/assessment/voice/results',
            builder: (context, state) => const ResultsView(),
          ),
        ],
      ),
      GoRoute(
        path: '/assessment/cookie-theft',
        builder: (context, state) => const CookieTheftScreen(),
      ),
      GoRoute(
        path: '/assessment/tug-test',
        builder: (context, state) => const TugTestScreen(),
      ),
      GoRoute(
        path: '/assessment/results',
        builder: (context, state) => const ResultsScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/view-medications',
        builder: (context, state) => const ViewMedicationsScreen(),
      ),
      GoRoute(
        path: '/add-medication',
        builder: (context, state) => const AddMedicationScreen(),
      ),
      GoRoute(
        path: '/consultation',
        builder: (context, state) => const ConsultationScreen(),
      ),
      GoRoute(
        path: '/voice-assistant',
        builder: (context, state) => const VoiceAssistantScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
}