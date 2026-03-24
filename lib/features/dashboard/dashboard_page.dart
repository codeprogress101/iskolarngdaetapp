import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../../core/services/feature_policy_service.dart';
import '../../core/services/local_notifications_service.dart';
import '../../ui/components/app_components.dart';
import '../../ui/components/app_shell.dart';
import '../../ui/theme/app_theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _latestApplication;
  String _incomeCertificateStatus = 'Not Uploaded';
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _recentNotifications = const [];
  Timer? _notificationPollTimer;
  bool _applicationIntakeOpen = true;
  String? _applicationIntakeMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _startNotificationPolling();
  }

  @override
  void dispose() {
    _notificationPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated applicant session found.');
      }

      final profile = await _supabase
          .from('profiles')
          .select('first_name, last_name, role, is_active')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        throw Exception('No profile found for this account.');
      }
      if ((profile['role'] ?? '').toString().trim() != 'applicant') {
        await _supabase.auth.signOut();
        if (!mounted) return;
        context.go('/login');
        return;
      }
      if (profile['is_active'] != true) {
        await _supabase.auth.signOut();
        if (!mounted) return;
        context.go(
          '/login?message=${Uri.encodeComponent("Your account is currently inactive. Please contact LDSP support.")}',
        );
        return;
      }

      final applications = await _supabase
          .from('applications')
          .select(
            'id, application_no, scholarship_type, school_year, status, submitted_at, created_at, updated_at',
          )
          .eq('applicant_id', user.id)
          .order('updated_at', ascending: false)
          .order('created_at', ascending: false)
          .limit(10);
      final latestApplication = (applications as List).isEmpty
          ? null
          : Map<String, dynamic>.from((applications).first as Map);

      final unreadNotifications = await _loadUnreadNotificationCount(user.id);
      final recentNotifications = await _loadRecentNotifications(user.id);
      final policy = await FeaturePolicyService(
        client: _supabase,
      ).fetchSnapshot();

      var documentStatus = 'Not Uploaded';
      final appId = latestApplication?['id'];
      if (appId != null) {
        final incomeDoc = await _supabase
            .from('application_documents')
            .select('verification_status, created_at')
            .eq('application_id', appId)
            .eq('document_type', 'income_certificate')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        documentStatus = _docStatusLabel(
          incomeDoc?['verification_status']?.toString(),
        );
      }

      if (!mounted) return;
      setState(() {
        _profile = Map<String, dynamic>.from(profile);
        _latestApplication = latestApplication;
        _incomeCertificateStatus = documentStatus;
        _unreadNotifications = unreadNotifications;
        _recentNotifications = recentNotifications;
        _applicationIntakeOpen = policy.applicationIntakeOpen;
        _applicationIntakeMessage = policy.applicationIntakeOpen
            ? null
            : policy.intakeClosedMessage();
      });
    } on PostgrestException catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Failed to load dashboard. Please try again.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isMissingColumnError(PostgrestException exception, String columnName) {
    final message = exception.message.toLowerCase();
    return message.contains('column') &&
        message.contains(columnName.toLowerCase());
  }

  Future<int> _loadUnreadNotificationCount(String userId) async {
    try {
      final withDismissedFilter = await _supabase
          .from('notifications')
          .select('id')
          .eq('recipient_user_id', userId)
          .eq('is_read', false)
          .isFilter('dismissed_at', null);
      return (withDismissedFilter as List).length;
    } on PostgrestException catch (e) {
      if (_isMissingColumnError(e, 'dismissed_at')) {
        final fallback = await _supabase
            .from('notifications')
            .select('id')
            .eq('recipient_user_id', userId)
            .eq('is_read', false);
        return (fallback as List).length;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecentNotifications(
    String userId,
  ) async {
    try {
      final rows = await _supabase
          .from('notifications')
          .select(
            'id, title, message, related_application_id, related_url, is_read, created_at',
          )
          .eq('recipient_user_id', userId)
          .isFilter('dismissed_at', null)
          .order('created_at', ascending: false)
          .limit(5);
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      if (_isMissingColumnError(e, 'dismissed_at')) {
        final fallback = await _supabase
            .from('notifications')
            .select(
              'id, title, message, related_application_id, related_url, is_read, created_at',
            )
            .eq('recipient_user_id', userId)
            .order('created_at', ascending: false)
            .limit(5);
        return List<Map<String, dynamic>>.from(fallback as List);
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  void _startNotificationPolling() {
    _notificationPollTimer?.cancel();
    _notificationPollTimer = Timer.periodic(const Duration(seconds: 20), (
      _,
    ) async {
      final user = _supabase.auth.currentUser;
      if (user == null || !mounted) return;
      final newCount = await _loadUnreadNotificationCount(user.id);
      if (!mounted) return;
      final had = _unreadNotifications;
      if (newCount > had) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You have $newCount unread notification${newCount == 1 ? '' : 's'}.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        unawaited(
          LocalNotificationsService.instance.showUnreadAlert(
            unreadCount: newCount,
            title: 'LDSP Notification',
            body:
                'You have $newCount unread notification${newCount == 1 ? '' : 's'}.',
          ),
        );
      }
      if (newCount != had) {
        setState(() {
          _unreadNotifications = newCount;
        });
      }
    });
  }

  String _statusLabel(String? status) {
    final normalized = (status ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return '-';
    return normalized
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _nextThingToDo(String? status) {
    const mapping = <String, String>{
      'draft': 'Complete your draft and submit your application.',
      'submitted': 'Wait for secretary screening and exam scheduling.',
      'pending_exam': 'Wait for your exam schedule.',
      'exam_scheduled': 'Prepare for your exam schedule.',
      'exam_completed': 'Wait for exam result encoding.',
      'passed_exam': 'Wait for interview schedule.',
      'for_interview': 'Prepare and attend your interview.',
      'interview_scheduled': 'Attend your scheduled interview.',
      'for_approval': 'Wait for final approval review.',
      'approved': 'Wait for release instructions.',
      'for_release': 'Wait for release schedule.',
      'returned_for_correction': 'Update and resubmit your application.',
    };
    return mapping[(status ?? '').toString().trim().toLowerCase()] ??
        'Wait for the next update from LDSP.';
  }

  String _docStatusLabel(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      case 'needs_reupload':
        return 'Needs Reupload';
      case 'pending':
        return 'For Review';
      default:
        return 'Not Uploaded';
    }
  }

  String _formatDateTime(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return '-';
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour24 = parsed.hour;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}, $hour12:$minute $period';
  }

  String _notificationSummary(Map<String, dynamic> row) {
    final title = (row['title'] ?? '').toString().trim();
    if (title.isNotEmpty) return 'Notification: $title';
    final msg = (row['message'] ?? '').toString().trim();
    if (msg.isEmpty) return 'Notification';
    final sentence = msg.split(RegExp(r'[.!?]')).first.trim();
    return sentence.isEmpty ? 'Notification' : 'Notification: $sentence';
  }

  List<({String label, String when})> _events() {
    final app = _latestApplication;
    final events = <({String label, String when})>[];
    if (app != null) {
      events.add((
        label: 'Draft created',
        when: _formatDateTime(app['created_at']),
      ));
      if ((app['submitted_at'] ?? '').toString().trim().isNotEmpty) {
        events.add((
          label: 'Application submitted',
          when: _formatDateTime(app['submitted_at']),
        ));
      }
      if ((app['updated_at'] ?? '').toString().trim().isNotEmpty) {
        events.add((
          label: 'Current status: ${_statusLabel(app['status']?.toString())}',
          when: _formatDateTime(app['updated_at']),
        ));
      }
    }
    for (final row in _recentNotifications) {
      events.add((
        label: _notificationSummary(row),
        when: _formatDateTime(row['created_at']),
      ));
    }
    return events.take(6).toList();
  }

  double _progressForStatus(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'draft':
        return 0.2;
      case 'returned_for_correction':
        return 0.45;
      case 'submitted':
        return 0.6;
      case 'pending_exam':
      case 'exam_scheduled':
      case 'exam_completed':
      case 'passed_exam':
        return 0.72;
      case 'for_interview':
      case 'interview_scheduled':
      case 'interview_completed':
        return 0.82;
      case 'for_approval':
        return 0.9;
      case 'approved':
      case 'for_release':
      case 'released':
        return 1.0;
      default:
        return 0.15;
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  void _openNewApplicationFlow() {
    final latest = _latestApplication;
    final latestId = (latest?['id'] ?? '').toString();
    final status = (latest?['status'] ?? '').toString().trim().toLowerCase();

    if (latestId.isEmpty) {
      if (!_applicationIntakeOpen) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _applicationIntakeMessage ??
                  'New application filing is currently closed by System Administrator.',
            ),
          ),
        );
        return;
      }
      context.push('/applications/new/edit');
      return;
    }

    if (status == 'draft' || status == 'returned_for_correction') {
      context.push('/applications/$latestId/edit');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Only one submitted application is allowed. Opening your current application instead.',
        ),
      ),
    );
    context.push('/applications/$latestId');
  }

  Widget _staggered({required Widget child, required int step}) {
    return RevealOnMount(delayMs: 40 * step, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final events = _events();
    final fullName =
        '${((_profile?['first_name'] ?? '').toString()).toUpperCase()} ${((_profile?['last_name'] ?? '').toString()).toUpperCase()}'
            .trim();
    final latestId = (_latestApplication?['id'] ?? '').toString();
    final latestStatus = (_latestApplication?['status'] ?? '').toString();
    final primaryActionLabel = latestId.isEmpty
        ? 'Start Application'
        : (latestStatus.toLowerCase() == 'draft' ||
              latestStatus.toLowerCase() == 'returned_for_correction')
        ? 'Continue Draft'
        : 'View Submitted Application';

    return ApplicantShellScaffold(
      title: 'Home',
      tab: ApplicantTab.home,
      actions: <Widget>[
        IconButton(
          onPressed: _loadDashboard,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(onPressed: _signOut, icon: const Icon(Icons.logout_rounded)),
      ],
      body: AnimatedPageState(
        stateKey: _isLoading
            ? 'loading'
            : (_errorMessage != null ? 'error' : 'content'),
        child: _isLoading
            ? const SkeletonList(count: 5)
            : _errorMessage != null
            ? ScreenSection(
                child: EmptyState(
                  title: 'Unable to load dashboard',
                  message: _errorMessage!,
                  actionLabel: 'Retry',
                  onAction: _loadDashboard,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadDashboard,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _staggered(
                      step: 1,
                      child: SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${fullName.isEmpty ? 'Applicant' : fullName}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Track your scholarship status, schedules, and next required action.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (_unreadNotifications > 0) ...[
                              const SizedBox(height: AppSpacing.sm),
                              StatusBadge(
                                text:
                                    '$_unreadNotifications unread notification${_unreadNotifications == 1 ? '' : 's'}',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SectionGap(),
                    _staggered(
                      step: 2,
                      child: SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_applicationIntakeMessage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFAEB),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFFFEC84B),
                                  ),
                                ),
                                child: Text(
                                  _applicationIntakeMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFFB54708),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            Text(
                              'Current Status',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _statusLabel(
                                _latestApplication?['status']?.toString(),
                              ),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (_latestApplication?['application_no'] ??
                                            'No application record yet')
                                        .toString(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                ),
                                StatusBadge(
                                  text:
                                      (_latestApplication?['school_year'] ??
                                              '-')
                                          .toString(),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: PrimaryButton(
                                    text: primaryActionLabel,
                                    onPressed: _openNewApplicationFlow,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: SecondaryButton(
                                    text: 'View All Applications',
                                    onPressed: () =>
                                        context.go('/applications'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SectionGap(),
                    _staggered(
                      step: 3,
                      child: SectionCard(
                        title: 'Next Required Action',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.task_alt_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _nextThingToDo(
                                  _latestApplication?['status']?.toString(),
                                ),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SectionGap(),
                    _staggered(
                      step: 4,
                      child: ProgressCard(
                        title: 'Application Progress',
                        value: _progressForStatus(
                          _latestApplication?['status']?.toString(),
                        ),
                        caption: _statusLabel(
                          _latestApplication?['status']?.toString(),
                        ),
                      ),
                    ),
                    const SectionGap(),
                    _staggered(
                      step: 5,
                      child: SectionCard(
                        title: 'Requirement Summary',
                        child: RequirementItem(
                          label: 'Tax Exemption Certificate (PDF)',
                          status: _incomeCertificateStatus,
                        ),
                      ),
                    ),
                    const SectionGap(),
                    _staggered(
                      step: 6,
                      child: SectionCard(
                        title: 'Recent Activity',
                        child: TimelineList(items: events),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
