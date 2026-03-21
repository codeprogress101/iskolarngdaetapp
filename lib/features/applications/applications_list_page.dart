import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/feature_policy_service.dart';
import '../../ui/components/app_components.dart';
import '../../ui/theme/app_theme.dart';

class ApplicationsListPage extends StatefulWidget {
  const ApplicationsListPage({super.key, this.initialMessage});

  final String? initialMessage;

  @override
  State<ApplicationsListPage> createState() => _ApplicationsListPageState();
}

class _ApplicationsListPageState extends State<ApplicationsListPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _applications = const [];
  bool _applicationIntakeOpen = true;
  String? _applicationIntakeMessage;
  String? _routeMessage;

  static const Set<String> _draftEditableStatuses = <String>{
    'draft',
    'returned_for_correction',
  };

  @override
  void initState() {
    super.initState();
    _routeMessage = widget.initialMessage;
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated applicant session found.');
      }

      final rows = await _supabase
          .from('applications')
          .select(
            'id, application_no, scholarship_type, school_year, status, submitted_at, created_at, updated_at, is_locked',
          )
          .eq('applicant_id', user.id)
          .order('updated_at', ascending: false)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 12));
      final policy = await FeaturePolicyService(
        client: _supabase,
      ).fetchSnapshot();

      if (!mounted) return;
      setState(() {
        _applications = List<Map<String, dynamic>>.from(rows as List);
        _applicationIntakeOpen = policy.applicationIntakeOpen;
        _applicationIntakeMessage = policy.applicationIntakeOpen
            ? null
            : policy.intakeClosedMessage();
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Request timed out while loading applications.',
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _buildPostgrestErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _buildPostgrestErrorMessage(PostgrestException exception) {
    final rawMessage = exception.message;
    final columnMatch = RegExp(
      r'column\s+([a-zA-Z0-9_]+\.[a-zA-Z0-9_]+)\s+does not exist',
      caseSensitive: false,
    ).firstMatch(rawMessage);
    final relationMatch = RegExp(
      r'relation\s+"?([a-zA-Z0-9_]+)"?\s+does not exist',
      caseSensitive: false,
    ).firstMatch(rawMessage);
    if (columnMatch != null) {
      return 'Schema mismatch: missing column `${columnMatch.group(1)}`.';
    }
    if (relationMatch != null) {
      return 'Schema mismatch: missing table `${relationMatch.group(1)}`.';
    }
    return 'Failed to load applications: $rawMessage';
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

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return '-';
    final parsed = DateTime.tryParse(rawDate)?.toLocal();
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
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }

  Map<String, dynamic>? _latestEditableDraft() {
    final editable = _applications.where((row) {
      final status = (row['status'] ?? '').toString().toLowerCase().trim();
      final locked = row['is_locked'] == true;
      return !locked && _draftEditableStatuses.contains(status);
    }).toList();
    if (editable.isEmpty) return null;
    editable.sort((a, b) {
      final aDate = DateTime.tryParse(
        (a['updated_at'] ?? a['created_at'] ?? '').toString(),
      );
      final bDate = DateTime.tryParse(
        (b['updated_at'] ?? b['created_at'] ?? '').toString(),
      );
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return editable.first;
  }

  void _openNewApplicationFlow() {
    final latest = _applications.isEmpty ? null : _applications.first;
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

  Future<void> _openNotifications() async {
    await context.push('/notifications');
    if (!mounted) return;
    await _loadApplications();
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  void _openMainMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text('Dashboard'),
                onTap: () {
                  Navigator.pop(context);
                  this.context.go('/dashboard');
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('My Applications'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_none_rounded),
                title: const Text('Notifications'),
                onTap: () {
                  Navigator.pop(context);
                  _openNotifications();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign Out'),
                onTap: () {
                  Navigator.pop(context);
                  _signOut();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openActions(Map<String, dynamic> row) {
    final appId = (row['id'] ?? '').toString();
    if (appId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open this application record.'),
        ),
      );
      return;
    }
    final editable = _isEditableRow(row);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.track_changes_outlined),
                title: const Text('Track Application'),
                onTap: () {
                  Navigator.pop(context);
                  this.context.push('/applications/$appId');
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Application'),
                enabled: editable,
                subtitle: editable
                    ? null
                    : const Text(
                        'This application is currently locked or not editable.',
                      ),
                onTap: !editable
                    ? null
                    : () {
                        Navigator.pop(context);
                        this.context.push('/applications/$appId/edit');
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isEditableRow(Map<String, dynamic> row) {
    final status = (row['status'] ?? '').toString().trim().toLowerCase();
    final locked = row['is_locked'] == true;
    return !locked &&
        <String>{'draft', 'returned_for_correction'}.contains(status);
  }

  Widget _applicationCard(Map<String, dynamic> row) {
    final appId = (row['id'] ?? '').toString();
    final applicationNo = (row['application_no'] ?? '-').toString();
    final grant = (row['scholarship_type'] ?? 'DEGREE COURSE').toString();
    final submittedOn = _formatDate(row['submitted_at']?.toString());
    final status = row['status']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: appId.trim().isEmpty
            ? null
            : () => context.push('/applications/$appId'),
        child: SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      applicationNo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  StatusBadge(text: _statusLabel(status)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              InfoRow(label: 'Program', value: grant),
              InfoRow(
                label: 'School Year',
                value: (row['school_year'] ?? '-').toString(),
              ),
              InfoRow(label: 'Submitted On', value: submittedOn),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      text: 'Track',
                      onPressed: appId.trim().isEmpty
                          ? null
                          : () => context.push('/applications/$appId'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: PrimaryButton(
                      text: 'Actions',
                      onPressed: () => _openActions(row),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestDraft = _latestEditableDraft();
    final latestDraftId = (latestDraft?['id'] ?? '').toString();

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: EmptyState(
                  title: 'Unable to load applications',
                  message: _errorMessage!,
                  actionLabel: 'Retry',
                  onAction: _loadApplications,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadApplications,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    AppHeader(
                      title: 'My Applications',
                      subtitle:
                          'Review, track, and continue your scholarship records.',
                      leading: IconButton(
                        onPressed: _openMainMenu,
                        icon: const Icon(Icons.menu),
                      ),
                      trailing: IconButton(
                        onPressed: _loadApplications,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if ((_routeMessage ?? '').trim().isNotEmpty) ...[
                      SectionCard(
                        child: Text(
                          _routeMessage!,
                          style: const TextStyle(color: Color(0xFFB54708)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (_applicationIntakeMessage != null) ...[
                      SectionCard(
                        child: Text(
                          _applicationIntakeMessage!,
                          style: const TextStyle(color: Color(0xFFB54708)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            text: 'New Application',
                            onPressed: _openNewApplicationFlow,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: SecondaryButton(
                            text: 'Continue Draft',
                            onPressed: latestDraftId.isEmpty
                                ? null
                                : () => context.push(
                                    '/applications/$latestDraftId/edit',
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_applications.isEmpty)
                      EmptyState(
                        title: 'No application records yet',
                        message:
                            'Start your scholarship application and track all updates here.',
                        actionLabel: 'Start Application',
                        onAction: _openNewApplicationFlow,
                      )
                    else
                      ..._applications.map(_applicationCard),
                  ],
                ),
              ),
      ),
    );
  }
}
