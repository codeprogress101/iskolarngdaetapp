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

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _policyLoading = true;
  bool _resendingVerification = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _confirmAccuracy = false;
  bool _registrationEnabled = true;
  int _resendCooldownSeconds = 0;
  Timer? _resendCooldownTimer;
  String? _verificationEmail;
  String? _registrationPolicyMessage;
  String? _registrationSchemaWarning;
  String? _error;
  String? _warning;
  String? _success;

  @override
  void initState() {
    super.initState();
    _loadFeaturePolicy();
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadFeaturePolicy() async {
    setState(() {
      _policyLoading = true;
      _registrationPolicyMessage = null;
      _registrationSchemaWarning = null;
    });
    try {
      final snapshot = await FeaturePolicyService().fetchSnapshot();
      if (!mounted) return;
      setState(() {
        _registrationEnabled = snapshot.registrationEnabled;
        _registrationSchemaWarning = snapshot.registrationSchemaWarning;
        _registrationPolicyMessage = snapshot.registrationEnabled
            ? null
            : 'New account registration is currently turned OFF by System Administrator.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _registrationEnabled = true;
        _registrationSchemaWarning =
            'Registration policy check failed: ${e.toString().replaceFirst('Exception: ', '')}.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _policyLoading = false;
        });
      }
    }
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

  Future<void> _resendVerification() async {
    final email = (_verificationEmail ?? _emailController.text)
        .trim()
        .toLowerCase();
    if (email.isEmpty) {
      setState(() {
        _warning = 'Enter your email address first.';
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
      _warning = null;
      _error = null;
      _success = null;
      _verificationEmail = email;
    });

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      if (!mounted) return;
      setState(() {
        _success =
            'A new confirmation email has been sent. Check your inbox or spam folder, then sign in after confirmation.';
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

  Future<void> _register() async {
    if (_policyLoading) return;
    if (!_registrationEnabled) {
      setState(() {
        _error =
            _registrationPolicyMessage ?? 'Registration is currently disabled.';
      });
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    if (!_confirmAccuracy) {
      setState(() {
        _error = 'Please confirm that your information is true and accurate.';
      });
      return;
    }

    final normalizedMobile = AuthValidators.normalizePhilippineMobile(
      _mobileController.text,
    );
    if (normalizedMobile == null) {
      setState(() {
        _error = 'Enter a valid mobile number (example: 09XXXXXXXXX).';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _warning = null;
      _success = null;
    });

    final supabase = Supabase.instance.client;
    final email = _emailController.text.trim().toLowerCase();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    try {
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: _passwordController.text,
        emailRedirectTo: _resolveEmailConfirmRedirectUrl(),
        data: <String, dynamic>{
          'first_name': firstName,
          'last_name': lastName,
          'mobile_number': normalizedMobile,
        },
      );

      final user = authResponse.user;
      if (user == null) {
        throw Exception('Registration failed. No user was returned.');
      }

      if (authResponse.session != null) {
        await supabase.from('profiles').upsert(<String, dynamic>{
          'id': user.id,
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'mobile_number': normalizedMobile,
          'role': 'applicant',
          'is_active': true,
        }, onConflict: 'id');
        await supabase.auth.signOut();
      }

      if (!mounted) return;
      setState(() {
        _verificationEmail = email;
        _success =
            'Registration successful. Check your email for confirmation before signing in.';
      });
      _startResendCooldown();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
      });
    } on PostgrestException catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Registration succeeded but profile setup is incomplete. Please sign in once your email is confirmed.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _resolveEmailConfirmRedirectUrl() {
    if (kIsWeb) {
      return Uri.base.resolve('login?mode=verify').toString();
    }
    return 'ldspapp://login?mode=verify';
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 540,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              title: 'Applicant Registration',
              subtitle: 'Create your LDSP account',
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 420;
                if (!twoColumns) {
                  return Column(
                    children: [
                      TextFormField(
                        controller: _firstNameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            AuthValidators.requiredText(value, 'first name'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lastNameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            AuthValidators.requiredText(value, 'last name'),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            AuthValidators.requiredText(value, 'first name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            AuthValidators.requiredText(value, 'last name'),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newUsername],
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                hintText: '09XXXXXXXXX',
                border: OutlineInputBorder(),
              ),
              validator: AuthValidators.mobileNumber,
            ),
            const SizedBox(height: 12),
            PasswordField(
              controller: _passwordController,
              label: 'Password',
              obscureText: _obscurePassword,
              onToggleVisibility: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              validator: AuthValidators.passwordPolicy,
            ),
            const SizedBox(height: 12),
            PasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _loading ? null : _register(),
              onToggleVisibility: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
              validator: (value) => AuthValidators.confirmPassword(
                value,
                _passwordController.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Password must be at least 12 characters and include uppercase, lowercase, number, and symbol.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _confirmAccuracy,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I confirm that my information is true and accurate.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: _loading
                  ? null
                  : (next) {
                      setState(() {
                        _confirmAccuracy = next ?? false;
                      });
                    },
            ),
            if (_success != null) ...[
              AuthMessageBanner(
                message: _success!,
                type: AuthBannerType.success,
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
            if (_registrationSchemaWarning != null) ...[
              AuthMessageBanner(
                message: _registrationSchemaWarning!,
                type: AuthBannerType.warning,
              ),
              const SizedBox(height: 12),
            ],
            if (_warning != null) ...[
              AuthMessageBanner(
                message: _warning!,
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
                onPressed: (_loading || _policyLoading || !_registrationEnabled)
                    ? null
                    : _register,
                child: Text(
                  _loading ? 'Creating Account...' : 'Create Applicant Account',
                ),
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
                      : _resendVerification,
                  child: Text(
                    _resendCooldownSeconds > 0
                        ? 'Resend Confirmation ($_resendCooldownSeconds)'
                        : (_resendingVerification
                              ? 'Sending...'
                              : 'Resend Confirmation Email'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          final email = Uri.encodeQueryComponent(
                            (_verificationEmail ?? '').trim(),
                          );
                          context.push('/verify-email-otp?email=$email');
                        },
                  child: const Text('Verify with OTP Code'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading ? null : () => context.go('/login'),
              child: const Text('Already registered? Back to login'),
            ),
          ],
        ),
      ),
    );
  }
}
