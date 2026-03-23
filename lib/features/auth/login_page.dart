import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/feature_policy_service.dart';
import 'auth_validators.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_message_banner.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/password_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialMessage});

  final String? initialMessage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _policyLoading = true;
  bool _resendingVerification = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  int _resendCooldownSeconds = 0;
  Timer? _resendCooldownTimer;
  bool _registrationEnabled = true;
  String? _verificationEmail;
  String? _error;
  String? _info;
  String? _warning;
  String? _registrationPolicyMessage;

  @override
  void initState() {
    super.initState();
    _info = widget.initialMessage;
    _loadFeaturePolicy();
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadFeaturePolicy() async {
    setState(() {
      _policyLoading = true;
      _registrationPolicyMessage = null;
    });
    try {
      final snapshot = await FeaturePolicyService().fetchSnapshot();
      if (!mounted) return;
      setState(() {
        _registrationEnabled = snapshot.registrationEnabled;
        _registrationPolicyMessage = snapshot.registrationEnabled
            ? null
            : 'New account registration is currently turned OFF by System Administrator.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _registrationEnabled = true;
        _registrationPolicyMessage = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _policyLoading = false;
        });
      }
    }
  }

  bool _isEmailNotConfirmed(AuthException exception) {
    final message = exception.message.toLowerCase();
    return message.contains('not confirmed') ||
        message.contains('email_not_confirmed') ||
        message.contains('email not confirmed');
  }

  void _startResendCooldown() {
    _resendCooldownTimer?.cancel();
    setState(() {
      _resendCooldownSeconds = 60;
    });
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _resendCooldownSeconds = 0;
        });
        return;
      }
      setState(() {
        _resendCooldownSeconds -= 1;
      });
    });
  }

  Future<void> _resendVerification({required bool automatic}) async {
    final email = (_verificationEmail ?? _emailController.text)
        .trim()
        .toLowerCase();
    if (email.isEmpty) {
      setState(() {
        _warning = 'Enter your email first, then try signing in again.';
      });
      return;
    }
    if (_resendCooldownSeconds > 0) {
      setState(() {
        _warning =
            'A confirmation email was already requested. Wait $_resendCooldownSeconds seconds before requesting again.';
      });
      return;
    }

    setState(() {
      _resendingVerification = true;
      _error = null;
      _warning = null;
      _info = null;
      _verificationEmail = email;
    });

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      if (!mounted) return;
      setState(() {
        _warning = automatic
            ? 'Your account is not verified yet. A new confirmation email has been sent automatically. Check inbox or spam before signing in again.'
            : 'A new confirmation email has been sent. Check inbox or spam before signing in again.';
      });
      _startResendCooldown();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _resendingVerification = false;
        });
      }
    }
  }

  Future<void> _login() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
      _warning = null;
    });

    final supabase = Supabase.instance.client;

    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Login failed. No authenticated user returned.');
      }

      final profile = await _loadProfile(user: user);

      if (profile == null) {
        await supabase.auth.signOut();
        throw Exception(
          'Login succeeded, but no matching applicant profile was found for this account. Please contact LDSP support.',
        );
      }

      final role = (profile['role'] ?? '').toString().trim();
      final isActive = profile['is_active'] == true;

      if (role != 'applicant') {
        await supabase.auth.signOut();
        throw Exception(
          'This mobile app is for applicants only. Current role: $role',
        );
      }

      if (!isActive) {
        await supabase.auth.signOut();
        throw Exception(
          'Your applicant account is inactive. Please contact LDSP support to reactivate access.',
        );
      }

      if (!mounted) return;
      context.go('/dashboard');
    } on AuthException catch (e) {
      if (_isEmailNotConfirmed(e)) {
        _verificationEmail = _emailController.text.trim().toLowerCase();
        await _resendVerification(automatic: true);
        return;
      }
      setState(() {
        _error = e.message;
      });
    } on PostgrestException catch (e) {
      if (kDebugMode) {
        debugPrint('POSTGREST ERROR: ${e.message}');
        debugPrint('POSTGREST DETAILS: ${e.details}');
        debugPrint('POSTGREST HINT: ${e.hint}');
        debugPrint('POSTGREST CODE: ${e.code}');
      }
      setState(() {
        _error =
            'We could not verify your account profile right now. Please try again.';
      });
    } catch (e) {
      if (kDebugMode) debugPrint('LOGIN ERROR: $e');
      setState(() {
        _error = _friendlyLoginError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _friendlyLoginError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    if (raw.contains('No host specified in URI') ||
        raw.contains('/auth/v1/token')) {
      return 'Supabase configuration is missing or invalid. Check .env keys SUPABASE_URL/LDSS_SUPABASE_URL and SUPABASE_ANON_KEY/LDSS_SUPABASE_ANON_KEY.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 500,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              title: 'LDSP',
              subtitle: 'LGU Daet Scholarship Portal',
              note: 'Official applicant sign in access.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _passwordController,
              label: 'Password',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _loading ? null : _login(),
              onToggleVisibility: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              validator: (value) =>
                  AuthValidators.requiredText(value, 'password'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: _loading
                      ? null
                      : (next) {
                          setState(() {
                            _rememberMe = next ?? false;
                          });
                        },
                ),
                const Text('Remember me'),
                const Spacer(),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => context.push('/forgot-password'),
                  child: const Text('Forgot password?'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_info != null) ...[
              AuthMessageBanner(message: _info!, type: AuthBannerType.info),
              const SizedBox(height: 12),
            ],
            if (_warning != null) ...[
              AuthMessageBanner(
                message: _warning!,
                type: AuthBannerType.warning,
              ),
              const SizedBox(height: 12),
            ],
            if (_registrationPolicyMessage != null) ...[
              AuthMessageBanner(
                message: _registrationPolicyMessage!,
                type: AuthBannerType.warning,
              ),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[
              AuthMessageBanner(message: _error!, type: AuthBannerType.error),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _loading ? null : _login,
                child: Text(_loading ? 'Signing In...' : 'Sign In'),
              ),
            ),
            if (_verificationEmail != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed:
                      (_resendingVerification || _resendCooldownSeconds > 0)
                      ? null
                      : () => _resendVerification(automatic: false),
                  child: Text(
                    _resendCooldownSeconds > 0
                        ? 'Resend Verification ($_resendCooldownSeconds)'
                        : (_resendingVerification
                              ? 'Sending...'
                              : 'Resend Verification Email'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextButton(
              onPressed: (_loading || _policyLoading || !_registrationEnabled)
                  ? null
                  : () {
                      context.push('/register');
                    },
              child: const Text(
                'Need an account? Register as Scholarship Applicant',
              ),
            ),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => context.push('/verify-email-otp'),
              child: const Text('Already have a code? Verify with OTP'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _loadProfile({
    required User user,
  }) async {
    final supabase = Supabase.instance.client;
    final profile = await supabase
        .from('profiles')
        .select('id, role, is_active, first_name, last_name, email')
        .eq('id', user.id)
        .maybeSingle();
    return profile == null ? null : Map<String, dynamic>.from(profile);
  }
}
