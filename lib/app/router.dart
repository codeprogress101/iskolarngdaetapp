import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/feature_policy_service.dart';
import '../features/applications/application_detail_page.dart';
import '../features/applications/application_edit_page.dart';
import '../features/applications/applications_list_page.dart';
import '../features/auth/forgot_password_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/reset_password_page.dart';
import '../features/auth/verify_email_otp_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/profile/profile_page.dart';
import '../features/splash/splash_page.dart';

final _authRefreshListenable = _AuthStateRefreshListenable(
  Supabase.instance.client.auth.onAuthStateChange,
);

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _authRefreshListenable,
  redirect: (context, state) async {
    final location = state.matchedLocation;
    final isDeepLinkRecovery =
        state.uri.scheme == 'ldspapp' && state.uri.host == 'reset-password';
    final isDeepLinkRegistrationVerify =
        state.uri.scheme == 'ldspapp' &&
        state.uri.host == 'login' &&
        state.uri.queryParameters['mode'] == 'verify';
    final isAuthPage =
        location == '/login' ||
        location == '/register' ||
        location == '/forgot-password' ||
        location == '/verify-email-otp';
    final isRegisterPage = location == '/register';
    final isResetPasswordPage = location == '/reset-password';
    final isNewApplicationEditPage = location == '/applications/new/edit';
    final isPublicPage = location == '/';
    final requiresApplicantAccess =
        location == '/dashboard' ||
        location == '/notifications' ||
        location == '/profile' ||
        location.startsWith('/applications');

    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    final user = supabase.auth.currentUser;
    final registerPolicy = await _resolveRegistrationRouteAccess();
    final intakePolicy = await _resolveApplicationIntakeRouteAccess();

    if (isDeepLinkRegistrationVerify) {
      await supabase.auth.signOut();
      return '/login?message=${Uri.encodeComponent("Email verified successfully. Please sign in.")}';
    }

    if (isDeepLinkRecovery) {
      _authRefreshListenable.markRecoveryFlow();
    }

    if (isDeepLinkRecovery || _authRefreshListenable.hasRecoveryFlow) {
      if (!isResetPasswordPage) {
        return '/reset-password?mode=recovery';
      }
    }

    if (isRegisterPage && !registerPolicy.isAllowed) {
      final reason = Uri.encodeComponent(registerPolicy.message);
      return '/login?message=$reason';
    }
    if (isResetPasswordPage && !_authRefreshListenable.hasRecoveryFlow) {
      return '/login?message=${Uri.encodeComponent("Open Reset Password from the recovery link sent to your email.")}';
    }
    if (isResetPasswordPage) {
      return null;
    }
    if (isNewApplicationEditPage && !intakePolicy.isAllowed) {
      final reason = Uri.encodeComponent(intakePolicy.message);
      return '/applications?message=$reason';
    }

    if (session == null || user == null) {
      if (requiresApplicantAccess) {
        return '/login?message=${Uri.encodeComponent("Please sign in to continue.")}';
      }
      return null;
    }

    final access = await _resolveApplicantAccess(userId: user.id);

    if (!access.isAllowed) {
      await supabase.auth.signOut();
      final reason = Uri.encodeComponent(access.message);
      final loginTarget = '/login?message=$reason';
      if (state.uri.toString() != loginTarget) {
        return loginTarget;
      }
      return null;
    }

    if (isPublicPage || isAuthPage) {
      return '/dashboard';
    }

    return null;
  },
  routes: <GoRoute>[
    GoRoute(path: '/', builder: (context, state) => const SplashPage()),
    GoRoute(
      path: '/login',
      builder: (context, state) {
        final message = state.uri.queryParameters['message'];
        final mode = state.uri.queryParameters['mode'];
        final initialMessage =
            message ??
            (mode == 'verify'
                ? 'Email verified successfully. Please sign in.'
                : null);
        return LoginPage(initialMessage: initialMessage);
      },
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: '/verify-email-otp',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'];
        return VerifyEmailOtpPage(initialEmail: email);
      },
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) {
        final mode = state.uri.queryParameters['mode'] ?? '';
        return ResetPasswordPage(fromRecoveryLink: mode == 'recovery');
      },
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsPage(),
    ),
    GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
    GoRoute(
      path: '/applications',
      builder: (context, state) {
        final message = state.uri.queryParameters['message'];
        return ApplicationsListPage(initialMessage: message);
      },
    ),
    GoRoute(
      path: '/applications/:id',
      builder: (context, state) {
        final appId = state.pathParameters['id'] ?? '';
        if (appId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('Invalid application id.')),
          );
        }
        return ApplicationDetailPage(appId: appId);
      },
    ),
    GoRoute(
      path: '/applications/:id/edit',
      builder: (context, state) {
        final appId = state.pathParameters['id'] ?? '';
        if (appId.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('Invalid application id.')),
          );
        }
        return ApplicationEditPage(appId: appId);
      },
    ),
  ],
);

class _AuthStateRefreshListenable extends ChangeNotifier {
  _AuthStateRefreshListenable(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((event) {
      if (event is AuthState) {
        final authState = event;
        if (authState.event == AuthChangeEvent.passwordRecovery) {
          _recoveryFlow = true;
        }
        if (authState.event == AuthChangeEvent.signedOut) {
          _recoveryFlow = false;
        }
      }
      notifyListeners();
    });
    _heartbeat = Timer.periodic(const Duration(seconds: 45), (_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;
  late final Timer _heartbeat;
  bool _recoveryFlow = false;

  bool get hasRecoveryFlow => _recoveryFlow;

  void markRecoveryFlow() {
    _recoveryFlow = true;
  }

  @override
  void dispose() {
    _heartbeat.cancel();
    _subscription.cancel();
    super.dispose();
  }
}

class _ApplicantAccessResult {
  const _ApplicantAccessResult({
    required this.isAllowed,
    required this.message,
  });

  final bool isAllowed;
  final String message;
}

class _RegistrationRouteAccessResult {
  const _RegistrationRouteAccessResult({
    required this.isAllowed,
    required this.message,
  });

  final bool isAllowed;
  final String message;
}

class _ApplicationIntakeRouteAccessResult {
  const _ApplicationIntakeRouteAccessResult({
    required this.isAllowed,
    required this.message,
  });

  final bool isAllowed;
  final String message;
}

Future<_ApplicantAccessResult> _resolveApplicantAccess({
  required String userId,
}) async {
  final supabase = Supabase.instance.client;

  try {
    final profile = await supabase
        .from('profiles')
        .select('role, is_active')
        .eq('id', userId)
        .maybeSingle();

    if (profile == null) {
      return const _ApplicantAccessResult(
        isAllowed: false,
        message:
            'Your account is missing a profile record. Please contact support.',
      );
    }

    final role = (profile['role'] ?? '').toString().trim();
    final isActive = profile['is_active'] == true;

    if (role != 'applicant') {
      return const _ApplicantAccessResult(
        isAllowed: false,
        message: 'This app only allows applicant accounts.',
      );
    }

    if (!isActive) {
      return const _ApplicantAccessResult(
        isAllowed: false,
        message:
            'Your applicant account is currently inactive. Please contact LDSP support.',
      );
    }

    return const _ApplicantAccessResult(isAllowed: true, message: '');
  } on PostgrestException catch (e) {
    if (kDebugMode) debugPrint('Router profile check failed: ${e.message}');
    return const _ApplicantAccessResult(
      isAllowed: false,
      message:
          'We could not verify your account right now. Please try again in a moment.',
    );
  } catch (e) {
    if (kDebugMode) debugPrint('Router unexpected profile check error: $e');
    return const _ApplicantAccessResult(
      isAllowed: false,
      message:
          'We could not verify your account right now. Please try again in a moment.',
    );
  }
}

Future<_RegistrationRouteAccessResult> _resolveRegistrationRouteAccess() async {
  try {
    final snapshot = await FeaturePolicyService().fetchSnapshot();
    if (!snapshot.registrationEnabled) {
      return const _RegistrationRouteAccessResult(
        isAllowed: false,
        message: 'Registration is currently disabled by System Administrator.',
      );
    }

    return const _RegistrationRouteAccessResult(isAllowed: true, message: '');
  } catch (e) {
    if (kDebugMode) debugPrint('Registration policy route check failed: $e');
    return const _RegistrationRouteAccessResult(
      isAllowed: false,
      message:
          'Registration is temporarily unavailable because policy checks could not be completed.',
    );
  }
}

Future<_ApplicationIntakeRouteAccessResult>
_resolveApplicationIntakeRouteAccess() async {
  try {
    final snapshot = await FeaturePolicyService().fetchSnapshot();
    if (!snapshot.applicationIntakeOpen) {
      return _ApplicationIntakeRouteAccessResult(
        isAllowed: false,
        message: snapshot.intakeClosedMessage(),
      );
    }
    return const _ApplicationIntakeRouteAccessResult(
      isAllowed: true,
      message: '',
    );
  } catch (_) {
    return const _ApplicationIntakeRouteAccessResult(
      isAllowed: false,
      message:
          'Application intake is temporarily unavailable because policy checks could not be completed.',
    );
  }
}
