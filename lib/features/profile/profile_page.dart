import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ui/components/app_components.dart';
import '../../ui/components/app_shell.dart';
import '../../ui/theme/app_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated applicant session found.');
      }

      final row = await _supabase
          .from('profiles')
          .select('first_name,last_name,email,mobile_number,role,is_active')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _profile = row == null ? null : Map<String, dynamic>.from(row);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load profile right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final fullName = profile == null
        ? '-'
        : '${(profile['first_name'] ?? '').toString()} ${(profile['last_name'] ?? '').toString()}'.trim();
    final isActive = profile?['is_active'] == true;

    return ApplicantShellScaffold(
      title: 'Profile',
      tab: ApplicantTab.profile,
      actions: <Widget>[
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: ScreenSection(
        child: AnimatedPageState(
          stateKey: _loading ? 'loading' : (_error != null ? 'error' : 'content'),
          child: _loading
              ? const SkeletonList(count: 3, padding: EdgeInsets.zero)
              : _error != null
              ? EmptyState(
                  title: 'Unable to load profile',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _load,
                )
              : ListView(
                children: [
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isEmpty ? '-' : fullName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        StatusBadge(
                          text: isActive ? 'Active Applicant' : 'Inactive',
                        ),
                      ],
                    ),
                  ),
                  const SectionGap(),
                  SectionCard(
                    title: 'Account Details',
                    child: Column(
                      children: [
                        InfoRow(
                          label: 'Email',
                          value: (profile?['email'] ?? '-').toString(),
                        ),
                        InfoRow(
                          label: 'Mobile',
                          value: (profile?['mobile_number'] ?? '-').toString(),
                        ),
                        InfoRow(
                          label: 'Role',
                          value: (profile?['role'] ?? '-').toString(),
                        ),
                      ],
                    ),
                  ),
                  const SectionGap(),
                  SectionCard(
                    title: 'Security',
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: SecondaryButton(
                            text: 'Forgot Password',
                            onPressed: () => context.push('/forgot-password'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            text: 'Sign Out',
                            onPressed: _signOut,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}
