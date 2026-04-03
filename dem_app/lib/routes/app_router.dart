import 'package:go_router/go_router.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/auth/profile_setup_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/assessment/assessment_overview_screen.dart';
import '../screens/assessment/mmse_test_screen.dart';
import '../screens/assessment/voice_analysis_screen.dart';
import '../screens/assessment/cookie_theft_screen.dart';
import '../screens/assessment/tug_test_screen.dart';
import '../screens/assessment/results_screen.dart';
import '../screens/medications/medications_screen.dart';
import '../screens/doctors/doctors_screen.dart';
import '../screens/consultation/consultation_screen.dart';
import '../screens/voice_assistant/voice_assistant_screen.dart';
import '../screens/profile/profile_screen.dart';

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
      GoRoute(
        path: '/assessment/voice-analysis',
        builder: (context, state) => const VoiceAnalysisScreen(),
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
        path: '/medications',
        builder: (context, state) => const MedicationsScreen(),
      ),
      GoRoute(
        path: '/doctors',
        builder: (context, state) => const DoctorsScreen(),
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