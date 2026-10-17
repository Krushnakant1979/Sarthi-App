import 'package:flutter_test/flutter_test.dart';
import 'package:sarthi_app/app/app_config.dart';

class RouterGuardSimulator {
  static String getInitialLocation(AppType appType) {
    switch (appType) {
      case AppType.user:
        return '/';
      case AppType.captain:
        return '/captain';
      case AppType.admin:
        return '/admin';
    }
  }

  static String? evaluateRedirect({
    required AppType appType,
    required bool isAuthLoading,
    required bool isAuthenticated,
    required bool isProfileLoading,
    required String? role,
    required String matchedLocation,
    String? aadhaarCardUrl,
    String? drivingLicenceUrl,
    String? verificationStatus,
  }) {
    final isAuthRoute = matchedLocation == '/login' ||
        matchedLocation == '/signup' ||
        matchedLocation == '/forgot-password';
    final isLoadingRoute = matchedLocation == '/loading';

    // 1. Auth initializing
    if (isAuthLoading) return '/loading';

    // 2. Unauthenticated
    if (!isAuthenticated) {
      if (isAuthRoute) return null;
      return '/login';
    }

    // 3. Profile loading
    if (isProfileLoading) return '/loading';

    // 4. Role mismatch
    bool isWrongApp = false;
    if (appType == AppType.user && role != 'user') isWrongApp = true;
    if (appType == AppType.captain && role != 'captain') isWrongApp = true;
    if (appType == AppType.admin && role != 'admin') isWrongApp = true;

    if (isWrongApp) {
      if (matchedLocation != '/login') return '/login';
      return null;
    }

    // 5. Captain document & KYC check
    if (role == 'captain') {
      final missingDocs =
          aadhaarCardUrl == null || drivingLicenceUrl == null;
      final isVerified = verificationStatus == 'verified';
      if ((missingDocs || !isVerified) &&
          matchedLocation != '/captain/documents') {
        return '/captain/documents';
      }
      if (!missingDocs && isVerified && matchedLocation == '/captain/documents') {
        return '/captain';
      }
    }

    // 6. Already authenticated on login / loading route -> send to home
    if (isAuthRoute || isLoadingRoute) {
      return getInitialLocation(appType);
    }

    // 7. Prevent cross-app '/' root confusion
    if (matchedLocation == '/') {
      if (appType == AppType.captain) return '/captain';
      if (appType == AppType.admin) return '/admin';
    }

    return null;
  }
}

void main() {
  group('Router Guards & Role Enforcement Tests', () {
    test('Initial location resolves correctly per AppType', () {
      expect(RouterGuardSimulator.getInitialLocation(AppType.user), '/');
      expect(RouterGuardSimulator.getInitialLocation(AppType.captain), '/captain');
      expect(RouterGuardSimulator.getInitialLocation(AppType.admin), '/admin');
    });

    test('Unauthenticated user is redirected to /login unless already on auth route', () {
      // Accessing root while logged out
      final redirectHome = RouterGuardSimulator.evaluateRedirect(
        appType: AppType.user,
        isAuthLoading: false,
        isAuthenticated: false,
        isProfileLoading: false,
        role: null,
        matchedLocation: '/',
      );
      expect(redirectHome, '/login');

      // Accessing /login while logged out -> allowed (null)
      final redirectLogin = RouterGuardSimulator.evaluateRedirect(
        appType: AppType.user,
        isAuthLoading: false,
        isAuthenticated: false,
        isProfileLoading: false,
        role: null,
        matchedLocation: '/login',
      );
      expect(redirectLogin, isNull);
    });

    test('Role mismatch between User App and Captain account redirects to login', () {
      final redirect = RouterGuardSimulator.evaluateRedirect(
        appType: AppType.user, // User app binary
        isAuthLoading: false,
        isAuthenticated: true,
        isProfileLoading: false,
        role: 'captain', // Logged in as Captain
        matchedLocation: '/',
      );
      expect(redirect, '/login');
    });

    test('Captain with missing documents is redirected to /captain/documents', () {
      final redirect = RouterGuardSimulator.evaluateRedirect(
        appType: AppType.captain,
        isAuthLoading: false,
        isAuthenticated: true,
        isProfileLoading: false,
        role: 'captain',
        matchedLocation: '/captain',
        aadhaarCardUrl: null, // missing aadhaar
        drivingLicenceUrl: 'https://example.com/dl.jpg',
        verificationStatus: 'pending',
      );
      expect(redirect, '/captain/documents');
    });

    test('Captain with uploaded documents but unverified status stays on /captain/documents', () {
      final redirect = RouterGuardSimulator.evaluateRedirect(
        appType: AppType.captain,
        isAuthLoading: false,
        isAuthenticated: true,
        isProfileLoading: false,
        role: 'captain',
        matchedLocation: '/captain',
        aadhaarCardUrl: 'https://example.com/aadhaar.jpg',
        drivingLicenceUrl: 'https://example.com/dl.jpg',
        verificationStatus: 'pending_review',
      );
      expect(redirect, '/captain/documents');
    });

    test('Verified captain is redirected to /captain if navigating to /captain/documents', () {
      final redirect = RouterGuardSimulator.evaluateRedirect(
        appType: AppType.captain,
        isAuthLoading: false,
        isAuthenticated: true,
        isProfileLoading: false,
        role: 'captain',
        matchedLocation: '/captain/documents',
        aadhaarCardUrl: 'https://example.com/aadhaar.jpg',
        drivingLicenceUrl: 'https://example.com/dl.jpg',
        verificationStatus: 'verified',
      );
      expect(redirect, '/captain');
    });

    test('Authenticated user on /login is redirected to their app initial location', () {
      final userRedirect = RouterGuardSimulator.evaluateRedirect(
        appType: AppType.user,
        isAuthLoading: false,
        isAuthenticated: true,
        isProfileLoading: false,
        role: 'user',
        matchedLocation: '/login',
      );
      expect(userRedirect, '/');

      final captainRedirect = RouterGuardSimulator.evaluateRedirect(
        appType: AppType.captain,
        isAuthLoading: false,
        isAuthenticated: true,
        isProfileLoading: false,
        role: 'captain',
        matchedLocation: '/login',
        aadhaarCardUrl: 'https://example.com/aadhaar.jpg',
        drivingLicenceUrl: 'https://example.com/dl.jpg',
        verificationStatus: 'verified',
      );
      expect(captainRedirect, '/captain');
    });
  });
}
