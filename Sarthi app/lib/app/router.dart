import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/user/map/presentation/map_home_screen.dart';
import '../features/shared/auth/presentation/login_screen.dart';
import '../features/shared/auth/presentation/signup_screen.dart';
import '../features/shared/auth/presentation/forgot_password_screen.dart';
import '../features/shared/auth/presentation/auth_providers.dart';
import '../features/user/map/presentation/search_screen.dart';
import '../features/admin/presentation/admin_dashboard_screen.dart';
import '../features/user/profile/presentation/legal_screen.dart';
import '../features/captain/presentation/captain_map_screen.dart';
import '../features/captain/presentation/captain_profile_screen.dart';
import '../features/captain/presentation/captain_document_upload_screen.dart';
import '../features/captain/presentation/captain_trips_screen.dart';
import '../features/user/profile/presentation/profile_screen.dart';
import '../features/user/profile/presentation/notifications_screen.dart';
import '../features/user/profile/presentation/rating_screen.dart';
import '../features/user/profile/presentation/safety_screen.dart';
import '../features/user/rides/presentation/ride_history_screen.dart';
import '../features/user/profile/presentation/support_tickets_screen.dart';
import 'app_config.dart';
import 'package:flutter/material.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final appConfig = ref.watch(appConfigProvider);

  // Helper for smooth fade transitions
  Page<void> fadeRoute(Widget child, GoRouterState state) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  String getInitialLocation() {
    switch (appConfig.appType) {
      case AppType.user:
        return '/';
      case AppType.captain:
        return '/captain';
      case AppType.admin:
        return '/admin';
    }
  }

  final router = GoRouter(
    initialLocation: getInitialLocation(),
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final currentUser = ref.read(currentUserProvider);

      final isAuth = authState.value != null;
      final loc = state.matchedLocation;
      final isAuthRoute =
          loc == '/login' || loc == '/signup' || loc == '/forgot-password';
      final isLoadingRoute = loc == '/loading';

      // 1. Wait for Firebase Auth to initialize
      if (authState.isLoading) {
        return '/loading';
      }

      // 2. Not logged in → go to login
      if (!isAuth) {
        if (isAuthRoute) return null; // Allow them to be on login/signup
        return '/login';
      }

      // 3. User is logged in. Now wait for Firestore profile to load.
      if (currentUser.isLoading && !currentUser.hasValue) {
        return '/loading';
      }

      // 4. Firestore profile is loaded. Check role restrictions.
      final appUser = currentUser.value;

      // Prevent race conditions during sign-up/login:
      // If their Firestore profile doesn't exist yet, give the UI a moment to create it.
      if (appUser == null) {
        return null; // Let them stay where they are or navigate to their destination
      }

      final role = appUser.role;
      bool isWrongApp = false;

      if (appConfig.appType == AppType.user && role != 'user') {
        isWrongApp = true;
      }
      if (appConfig.appType == AppType.captain && role != 'captain') {
        isWrongApp = true;
      }
      if (appConfig.appType == AppType.admin && role != 'admin') {
        isWrongApp = true;
      }

      if (isWrongApp) {
        // Log them out and prevent redirect loop by returning /login only if not already there
        Future.microtask(() {
          ref.read(authRepositoryProvider).signOut();
        });
        if (loc != '/login') return '/login';
        return null; // Stop looping if already at /login while signout is pending
      }

      // Check if captain needs to upload documents
      if (role == 'captain') {
        final missingDocs =
            appUser.aadhaarCardUrl == null || appUser.drivingLicenceUrl == null;
        final isVerified = appUser.verificationStatus == 'verified';
        if ((missingDocs || !isVerified) && loc != '/captain/documents') {
          return '/captain/documents';
        }
        if (!missingDocs && isVerified && loc == '/captain/documents') {
          return '/captain';
        }
      }

      // 5. If on an auth route or loading route but logged in correctly, route to home
      if (isAuthRoute || isLoadingRoute) {
        return getInitialLocation();
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        pageBuilder: (context, state) => fadeRoute(
          const Scaffold(body: Center(child: CircularProgressIndicator())),
          state,
        ),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            fadeRoute(const MapHomeScreen(), state),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => fadeRoute(const LoginScreen(), state),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => fadeRoute(const SignupScreen(), state),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) =>
            fadeRoute(const ForgotPasswordScreen(), state),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return fadeRoute(
            SearchScreen(
              initialPickup: extra?['pickup'] as Map<String, dynamic>?,
              initialDestination:
                  extra?['destination'] as Map<String, dynamic>?,
            ),
            state,
          );
        },
      ),
      GoRoute(
        path: '/admin',
        pageBuilder: (context, state) =>
            fadeRoute(const AdminDashboardScreen(), state),
      ),
      GoRoute(
        path: '/legal',
        pageBuilder: (context, state) => fadeRoute(const LegalScreen(), state),
      ),
      GoRoute(
        path: '/captain',
        pageBuilder: (context, state) =>
            fadeRoute(const CaptainMapScreen(), state),
      ),
      GoRoute(
        path: '/captain/trips',
        pageBuilder: (context, state) =>
            fadeRoute(const CaptainTripsScreen(), state),
      ),
      GoRoute(
        path: '/captain/profile',
        pageBuilder: (context, state) =>
            fadeRoute(const CaptainProfileScreen(), state),
      ),
      GoRoute(
        path: '/captain/documents',
        pageBuilder: (context, state) =>
            fadeRoute(const CaptainDocumentUploadScreen(), state),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) =>
            fadeRoute(const ProfileScreen(), state),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) =>
            fadeRoute(const NotificationsScreen(), state),
      ),
      GoRoute(
        path: '/rating',
        pageBuilder: (context, state) => fadeRoute(const RatingScreen(), state),
      ),
      GoRoute(
        path: '/safety',
        pageBuilder: (context, state) => fadeRoute(const SafetyScreen(), state),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (context, state) =>
            fadeRoute(const RideHistoryScreen(), state),
      ),
      GoRoute(
        path: '/support',
        pageBuilder: (context, state) =>
            fadeRoute(const SupportTicketsScreen(), state),
      ),
    ],
  );

  // Trigger a router refresh instead of recreating the GoRouter instance
  ref.listen(authStateProvider, (_, _) => router.refresh());
  ref.listen(currentUserProvider, (_, _) => router.refresh());

  return router;
});
