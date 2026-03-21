import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String _status = 'Checking session...';

  void _go(String route, {String? message}) {
    if (!mounted) return;
    if (message != null && message.isNotEmpty) {
      final encoded = Uri.encodeComponent(message);
      GoRouter.of(context).go('$route?message=$encoded');
      return;
    }
    GoRouter.of(context).go(route);
  }

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final supabase = Supabase.instance.client;

    try {
      setState(() {
        _status = 'Reading current session...';
      });

      final session = supabase.auth.currentSession;

      if (session == null) {
        _go('/login');
        return;
      }

      setState(() {
        _status = 'Loading applicant profile...';
      });

      final userId = session.user.id;

      final profile = await supabase
          .from('profiles')
          .select('role, is_active, first_name, last_name')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (profile == null) {
        await supabase.auth.signOut();
        _go(
          '/login',
          message:
              'Your account profile could not be found. Please contact support.',
        );
        return;
      }

      final role = (profile['role'] ?? '').toString().trim();
      final isActive = profile['is_active'] == true;

      if (!mounted) return;

      if (role == 'applicant' && isActive) {
        _go('/dashboard');
      } else {
        await supabase.auth.signOut();
        if (role != 'applicant') {
          _go('/login', message: 'This app only allows applicant accounts.');
          return;
        }
        _go(
          '/login',
          message:
              'Your applicant account is inactive. Please contact LDSP support.',
        );
      }
    } on PostgrestException catch (e, st) {
      if (kDebugMode) {
        debugPrint('Splash profile query failed: ${e.message}');
        debugPrintStack(stackTrace: st);
      }
      await supabase.auth.signOut();

      if (!mounted) return;
      _go(
        '/login',
        message:
            'We could not verify your account. Please try again. If this keeps happening, contact support.',
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Splash error: $e');
        debugPrintStack(stackTrace: st);
      }
      await supabase.auth.signOut();

      if (!mounted) return;

      _go(
        '/login',
        message:
            'We could not verify your session. Please sign in again. If this keeps happening, contact support.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/reference/img/daet-lgu.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.account_balance, size: 88),
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
