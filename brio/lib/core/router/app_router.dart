import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/notifiers/auth_notifier.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/onboarding_goal_page.dart';
import '../../features/auth/presentation/pages/onboarding_stats_page.dart';
import '../../features/dashboard/presentation/pages/main_shell_page.dart';
import '../../features/dashboard/presentation/pages/home_page.dart';
import '../../features/nutrition/presentation/pages/nutrition_page.dart';
import '../../features/nutrition/presentation/pages/food_search_page.dart';
import '../../features/nutrition/presentation/pages/create_meal_page.dart';
import '../../features/nutrition/presentation/pages/create_food_page.dart';
import '../../features/nutrition/presentation/pages/barcode_scanner_page.dart';
import '../../features/training/presentation/pages/training_page.dart';
import '../../features/training/presentation/pages/active_session_page.dart';
import '../../features/training/presentation/pages/history_page.dart';
import '../../features/training/presentation/pages/routine_detail_page.dart';
import '../../features/training/presentation/pages/workout_session_detail_page.dart';
import '../../features/training/presentation/pages/exercise_detail_page.dart';
import '../../features/training/presentation/pages/log_activity_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/training/presentation/pages/gps_tracking_page.dart';
import '../../features/training/presentation/pages/activity_share_page.dart';
import '../../features/training/presentation/pages/activity_detail_page.dart';
import '../../features/training/presentation/providers/activity_providers.dart';
import '../../features/social/presentation/pages/progress_page.dart';
import '../../features/social/presentation/pages/create_post_page.dart';
import '../../features/social/presentation/pages/post_detail_page.dart';
import '../../features/social/presentation/pages/user_search_page.dart';
import '../../features/social/presentation/pages/user_profile_page.dart';
import '../../features/social/domain/entities/social_entities.dart';
import '../../features/training/presentation/pages/plan_generator_page.dart';
import '../../features/training/presentation/pages/weekly_schedule_page.dart';

// Named routes — avoids scattering raw path strings across the app.
abstract final class AppRoutes {
  static const splash          = '/';
  static const login           = '/login';
  static const register        = '/register';
  static const onboardingGoal  = '/onboarding/goal';
  static const onboardingStats = '/onboarding/stats';
  static const home            = '/home';
  static const nutrition       = '/nutrition';
  static const training        = '/training';
  static const progress        = '/progress';
  static const profile         = '/profile';
  static const activeSession   = '/session';
  static const history         = '/history';
  static const routineDetail   = '/routine';   // + /{id}
  static const routineNew      = '/routine-new';
  static const workoutDetail   = '/workout';   // + /{id}
  static const exerciseDetail  = '/exercise';  // + /{id}
  static const logActivity     = '/log-activity';
  static const gpsTracking     = '/gps-tracking';
  static const activityShare   = '/activity-share';
  static const activityDetail  = '/activity-detail';
  static const foodSearch      = '/food-search';
  static const createMeal      = '/create-meal';
  static const createFood      = '/create-food';
  static const barcodeScanner  = '/barcode-scanner';
  static const createPost      = '/create-post';
  static const postDetail      = '/post-detail';
  static const userSearch      = '/user-search';
  static const userProfile     = '/user-profile';   // + /{id}
  static const planGenerator   = '/plan-generator';
  static const weeklySchedule  = '/weekly-schedule';
}

// IMPORTANT: the GoRouter is created ONCE. We don't use ref.watch here — that
// would recreate the router on every auth change and reset to splash. State is
// read with ref.read inside the redirect, and the refreshListenable (which
// listens to authNotifierProvider) triggers re-evaluation.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState       = ref.read(authNotifierProvider);
      final isAuthenticated = authState.valueOrNull?.isAuthenticated ?? false;
      final isLoading       = authState.isLoading || !authState.hasValue;
      final path            = state.matchedLocation;

      // Stay on splash while the initial state resolves.
      if (isLoading) {
        return path == AppRoutes.splash ? null : AppRoutes.splash;
      }

      const publicRoutes = [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.onboardingGoal,
        AppRoutes.onboardingStats,
      ];

      // Unauthenticated on a private route (or resolved splash) → login.
      if (!isAuthenticated &&
          !publicRoutes.contains(path)) {
        return AppRoutes.login;
      }
      // Authenticated on splash / login / register → home.
      if (isAuthenticated &&
          (path == AppRoutes.splash ||
           path == AppRoutes.login ||
           path == AppRoutes.register)) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash,          builder: (_, __) => const SplashPage()),
      GoRoute(path: AppRoutes.login,           builder: (_, __) => const LoginPage()),
      GoRoute(path: AppRoutes.register,        builder: (_, __) => const RegisterPage()),
      GoRoute(path: AppRoutes.onboardingGoal,  builder: (_, __) => const OnboardingGoalPage()),
      GoRoute(path: AppRoutes.onboardingStats, builder: (_, s) {
        final goal = s.uri.queryParameters['goal'] ?? 'maintain';
        return OnboardingStatsPage(goal: goal);
      }),
      // Full-screen pages outside the tabbed shell.
      GoRoute(path: AppRoutes.activeSession, builder: (_, __) => const ActiveSessionPage()),
      GoRoute(path: AppRoutes.history,       builder: (_, __) => const HistoryPage()),
      GoRoute(path: AppRoutes.routineNew,    builder: (_, __) => const RoutineDetailPage()),
      GoRoute(
        path: '${AppRoutes.routineDetail}/:id',
        builder: (_, s) => RoutineDetailPage(
          routineId: int.parse(s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.workoutDetail}/:id',
        builder: (_, s) => WorkoutSessionDetailPage(
          sessionId: int.parse(s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.exerciseDetail}/:id',
        builder: (_, s) => ExerciseDetailPage(
          exerciseId: int.parse(s.pathParameters['id']!),
        ),
      ),
      GoRoute(path: AppRoutes.logActivity, builder: (_, __) => const LogActivityPage()),
      GoRoute(
        path: AppRoutes.gpsTracking,
        builder: (_, s) => GpsTrackingPage(activity: s.extra as ActivityType),
      ),
      GoRoute(
        path: AppRoutes.activityShare,
        builder: (_, s) => ActivitySharePage(data: s.extra as ActivityShareData),
      ),
      GoRoute(
        path: AppRoutes.activityDetail,
        builder: (_, s) => ActivityDetailPage(activity: s.extra as ActivityLogEntry),
      ),
      GoRoute(
        path: AppRoutes.foodSearch,
        builder: (_, s) => FoodSearchPage(args: s.extra as FoodSearchArgs),
      ),
      GoRoute(
        path: AppRoutes.createMeal,
        builder: (_, __) => const CreateMealPage(),
      ),
      GoRoute(
        path: AppRoutes.createFood,
        builder: (_, __) => const CreateFoodPage(),
      ),
      GoRoute(
        path: AppRoutes.barcodeScanner,
        builder: (_, __) => const BarcodeScannerPage(),
      ),
      GoRoute(
        path: AppRoutes.createPost,
        builder: (_, __) => const CreatePostPage(),
      ),
      GoRoute(
        path: AppRoutes.postDetail,
        builder: (_, s) => PostDetailPage(post: s.extra as Post),
      ),
      GoRoute(
        path: AppRoutes.userSearch,
        builder: (_, __) => const UserSearchPage(),
      ),
      GoRoute(
        path: '${AppRoutes.userProfile}/:id',
        builder: (_, s) => UserProfilePage(userId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: AppRoutes.planGenerator,
        builder: (_, __) => const PlanGeneratorPage(),
      ),
      GoRoute(
        path: AppRoutes.weeklySchedule,
        builder: (_, __) => const WeeklySchedulePage(),
      ),
      ShellRoute(
        builder: (_, __, child) => MainShellPage(child: child),
        routes: [
          GoRoute(path: AppRoutes.home,      builder: (_, __) => const HomePage()),
          GoRoute(path: AppRoutes.nutrition, builder: (_, __) => const NutritionPage()),
          GoRoute(path: AppRoutes.training,  builder: (_, __) => const TrainingPage()),
          GoRoute(path: AppRoutes.progress,  builder: (_, __) => const ProgressPage()),
          GoRoute(path: AppRoutes.profile,   builder: (_, __) => const ProfilePage()),
        ],
      ),
    ],
  );
});

// Listens to authNotifierProvider changes and notifies go_router.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}
