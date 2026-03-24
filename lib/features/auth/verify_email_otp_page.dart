import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_validators.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_message_banner.dart';
import 'widgets/auth_scaffold.dart';

class VerifyEmailOtpPage extends StatefulWidget {
  const VerifyEmailOtpPage({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<VerifyEmailOtpPage> createState() => _VerifyEmailOtpPageState();
}

class _VerifyEmailOtpPageState extends State<VerifyEmailOtpPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _otpController = TextEditingController();

  bool _verifying = false;
  bool _resending = false;
  int _resendCooldownSeconds = 0;
  Timer? _resendCooldownTimer;
  String? _error;
  String? _warning;
  String? _success;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(
      text: (widget.initialEmail ?? '').trim().toLowerCase(),
    );
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String? _otpValidator(String? value) {
    final token = (value ?? '').trim();
    if (token.isEmpty) {
      return 'Please enter the OTP code.';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(token) &&
        !RegExp(r'^\d{8}$').hasMatch(token)) {
      return 'Enter the 6- or 8-digit OTP code from your email.';
    }
    return null;
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

  Future<void> _verifyOtp() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() {
      _verifying = true;
      _error = null;
      _warning = null;
      _success = null;
    });

    final email = _emailController.text.trim().toLowerCase();
    final token = _otpController.text.trim();

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );

      if (!mounted) return;
      setState(() {
        _success = 'Email verified successfully. Redirecting to login...';
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      context.go(
        '/login?message=${Uri.encodeComponent("Email verified successfully. Please sign in.")}',
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      setState(() {
        if (msg.contains('expired')) {
          _warning = 'OTP expired. Request a new code and try again.';
        } else if (msg.contains('invalid')) {
          _error = 'Invalid OTP code. Check your email and try again.';
        } else {
          _error = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'OTP verification failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _verifying = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    final emailError = AuthValidators.email(_emailController.text);
    if (emailError != null) {
      setState(() {
        _error = emailError;
        _warning = null;
        _success = null;
      });
      return;
    }
    if (_resendCooldownSeconds > 0) {
      setState(() {
        _warning =
            'A code was recently requested. Wait $_resendCooldownSeconds seconds before requesting again.';
      });
      return;
    }

    setState(() {
      _resending = true;
      _error = null;
      _warning = null;
      _success = null;
    });

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: _emailController.text.trim().toLowerCase(),
      );
      if (!mounted) return;
      setState(() {
        _success = 'A new verification code has been sent to your email.';
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
        _error = 'Unable to resend OTP code right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _resending = false;
        });
      }
    }
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
              title: 'Verify Account',
              subtitle: 'Confirm your email using the OTP code',
              note: 'Enter the 6- or 8-digit code sent to your email.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _verifying ? null : _verifyOtp(),
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'OTP Code',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              validator: _otpValidator,
            ),
            const SizedBox(height: 8),
            if (_success != null) ...[
              AuthMessageBanner(
                message: _success!,
                type: AuthBannerType.success,
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
                onPressed: _verifying ? null : _verifyOtp,
                child: Text(_verifying ? 'Verifying...' : 'Verify Account'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: (_resending || _resendCooldownSeconds > 0)
                    ? null
                    : _resendOtp,
                child: Text(
                  _resendCooldownSeconds > 0
                      ? 'Resend OTP ($_resendCooldownSeconds)'
                      : (_resending ? 'Sending...' : 'Resend OTP'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: (_verifying || _resending)
                  ? null
                  : () => context.go('/login'),
              child: const Text('Back to login'),
            ),
          ],
        ),
      ),
    );
  }
}
