import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_validators.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_message_banner.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/password_field.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, this.fromRecoveryLink = false});

  final bool fromRecoveryLink;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _checkingSession = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _hasValidRecoverySession = false;
  String? _error;
  String? _success;
  String? _warning;

  @override
  void initState() {
    super.initState();
    _checkRecoverySession();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkRecoverySession() async {
    setState(() {
      _checkingSession = true;
      _error = null;
      _warning = null;
      _hasValidRecoverySession = false;
    });
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (!mounted) return;
      if (session == null) {
        setState(() {
          _warning =
              'No active recovery session found. Use Forgot Password again.';
        });
      } else if (!widget.fromRecoveryLink) {
        setState(() {
          _warning =
              'Open this page from your email reset link to continue password recovery.';
        });
      } else {
        setState(() {
          _hasValidRecoverySession = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _warning = 'Recovery session check failed. Reopen your reset link.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingSession = false;
        });
      }
    }
  }

  Future<void> _updatePassword() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (!_hasValidRecoverySession) {
      setState(() {
        _warning =
            'No valid recovery session found. Open the latest reset link from your email.';
      });
      return;
    }

    final currentSession = Supabase.instance.client.auth.currentSession;
    if (currentSession == null) {
      setState(() {
        _warning =
            'No active recovery session found. Use Forgot Password again.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
      _warning = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      if (!mounted) return;
      setState(() {
        _success = 'Password updated successfully. Redirecting to login...';
      });
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      context.go(
        '/login?message=${Uri.encodeComponent("Password updated successfully. Please sign in.")}',
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        final msg = e.message.toLowerCase();
        if (msg.contains('expired') || msg.contains('invalid')) {
          _error =
              'This recovery session is invalid or expired. Request a new reset email.';
          return;
        }
        _error =
            'Password update failed. Please check your password and try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Password update failed.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
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
              title: 'Set New Password',
              subtitle: 'Enter your new password to complete account recovery.',
            ),
            const SizedBox(height: 24),
            PasswordField(
              controller: _passwordController,
              label: 'New Password',
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
              label: 'Confirm New Password',
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _loading ? null : _updatePassword(),
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
            const SizedBox(height: 10),
            Text(
              'Use at least 12 characters with uppercase, lowercase, number, and symbol.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            if (_checkingSession)
              const Center(child: CircularProgressIndicator())
            else ...[
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
                  onPressed:
                      (_loading || !_hasValidRecoverySession)
                      ? null
                      : _updatePassword,
                  child: Text(_loading ? 'Updating...' : 'Update Password'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : () => context.go('/login'),
                child: const Text('Back to login'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
