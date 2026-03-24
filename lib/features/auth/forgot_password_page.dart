import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_validators.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_message_banner.dart';
import 'widgets/auth_scaffold.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _sending = false;
  String? _error;
  String? _success;
  String? _warning;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String _resolveRedirectUrl() {
    if (kIsWeb) {
      return Uri.base.resolve('reset-password?mode=recovery').toString();
    }
    return 'ldspapp://reset-password?mode=recovery';
  }

  Future<void> _sendRecoveryEmail() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() {
      _sending = true;
      _error = null;
      _success = null;
      _warning = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim().toLowerCase(),
        redirectTo: _resolveRedirectUrl(),
      );
      if (!mounted) return;
      setState(() {
        _success =
            'Recovery email sent. Check your inbox and open the reset link.';
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        final msg = e.message.toLowerCase();
        if (msg.contains('rate') || msg.contains('too many')) {
          _warning =
              'Email rate limit exceeded. Wait at least 60 seconds, then try again.';
        } else {
          _error =
              'Could not send recovery email right now. Please try again in a moment.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            'Unexpected error while sending recovery email: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
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
              title: 'Forgot Password',
              subtitle: 'Recover your LDSP applicant account access',
              note: 'Enter your registered email address.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sending ? null : _sendRecoveryEmail(),
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 14),
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
                onPressed: _sending ? null : _sendRecoveryEmail,
                child: Text(_sending ? 'Sending...' : 'Send Recovery Email'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _sending ? null : () => context.go('/login'),
              child: const Text('Back to login'),
            ),
          ],
        ),
      ),
    );
  }
}
