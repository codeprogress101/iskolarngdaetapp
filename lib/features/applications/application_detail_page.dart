import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ui/components/app_components.dart';
import '../../ui/theme/app_theme.dart';

class ApplicationDetailPage extends StatefulWidget {
  const ApplicationDetailPage({required this.appId, super.key});

  final String appId;

  @override
  State<ApplicationDetailPage> createState() => _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends State<ApplicationDetailPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _application;
  List<Map<String, dynamic>> _documents = <Map<String, dynamic>>[];
  Map<String, dynamic>? _examRecord;
  Map<String, dynamic>? _interviewRecord;
  String? _documentsError;
  String? _examError;
  String? _interviewError;

  @override
  void initState() {
    super.initState();
    _loadApplication();
  }

  Future<void> _loadApplication() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _documentsError = null;
      _examError = null;
      _interviewError = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated applicant session found.');
      }

      final row = await _supabase
          .from('applications')
          .select(
            'id, application_no, scholarship_type, school_year, status, submitted_at, created_at, updated_at, is_locked, secretary_remarks',
          )
          .eq('id', widget.appId)
          .eq('applicant_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 12));

      if (row == null) {
        if (!mounted) return;
        setState(() => _application = null);
        return;
      }

      final appId = (row['id'] ?? '').toString();
      final docsResult = await _fetchDocuments(appId);
      final examResult = await _fetchExamRecord(appId);
      final interviewResult = await _fetchInterviewRecord(appId);

      if (!mounted) return;
      setState(() {
        _application = Map<String, dynamic>.from(row);
        _documents = docsResult.data ?? <Map<String, dynamic>>[];
        _examRecord = examResult.data;
        _interviewRecord = interviewResult.data;
        _documentsError = docsResult.errorMessage;
        _examError = examResult.errorMessage;
        _interviewError = interviewResult.errorMessage;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'Request timed out while loading application details.',
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

  bool _isSchemaMismatch(PostgrestException exception) {
    final message = exception.message.toLowerCase();
    return (message.contains('column') && message.contains('does not exist')) ||
        (message.contains('relation') && message.contains('does not exist'));
  }

  String _buildPostgrestErrorMessage(PostgrestException exception) {
    if (_isSchemaMismatch(exception)) {
      return 'Schema mismatch: ${exception.message}';
    }
    return 'Failed to load application details: ${exception.message}';
  }

  String _buildSectionErrorMessage(
    PostgrestException exception,
    String sectionLabel,
  ) {
    if (_isSchemaMismatch(exception)) {
      return 'Schema mismatch in $sectionLabel: ${exception.message}';
    }
    return 'Failed to load $sectionLabel: ${exception.message}';
  }

  Future<_SectionLoadResult<List<Map<String, dynamic>>>> _fetchDocuments(
    String appId,
  ) async {
    try {
      final result = await _supabase
          .from('application_documents')
          .select('document_type, verification_status, created_at')
          .eq('application_id', appId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 12));
      return _SectionLoadResult<List<Map<String, dynamic>>>(
        data: List<Map<String, dynamic>>.from(result as List),
      );
    } on PostgrestException catch (e) {
      return _SectionLoadResult<List<Map<String, dynamic>>>(
        errorMessage: _buildSectionErrorMessage(e, 'requirement documents'),
      );
    } on TimeoutException {
      return const _SectionLoadResult<List<Map<String, dynamic>>>(
        errorMessage: 'Request timed out while loading requirement documents.',
      );
    } catch (e) {
      return _SectionLoadResult<List<Map<String, dynamic>>>(
        errorMessage: e.toString().replaceFirst(
          'Exception: ',
          'Failed loading documents: ',
        ),
      );
    }
  }

  Future<_SectionLoadResult<Map<String, dynamic>?>> _fetchExamRecord(
    String appId,
  ) async {
    try {
      final result = await _supabase
          .from('exam_records')
          .select(
            'application_id, exam_control_no, raw_score, percentage_score, result, status, updated_at',
          )
          .eq('application_id', appId)
          .maybeSingle()
          .timeout(const Duration(seconds: 12));
      return _SectionLoadResult<Map<String, dynamic>?>(
        data: result == null ? null : Map<String, dynamic>.from(result),
      );
    } on PostgrestException catch (e) {
      return _SectionLoadResult<Map<String, dynamic>?>(
        errorMessage: _buildSectionErrorMessage(e, 'exam section'),
      );
    } on TimeoutException {
      return const _SectionLoadResult<Map<String, dynamic>?>(
        errorMessage: 'Request timed out while loading exam section.',
      );
    } catch (e) {
      return _SectionLoadResult<Map<String, dynamic>?>(
        errorMessage: e.toString().replaceFirst(
          'Exception: ',
          'Failed loading exam data: ',
        ),
      );
    }
  }

  Future<_SectionLoadResult<Map<String, dynamic>?>> _fetchInterviewRecord(
    String appId,
  ) async {
    try {
      final result = await _supabase
          .from('interview_records')
          .select(
            'application_id, scheduled_at, venue, status, result, remarks, updated_at',
          )
          .eq('application_id', appId)
          .maybeSingle()
          .timeout(const Duration(seconds: 12));
      return _SectionLoadResult<Map<String, dynamic>?>(
        data: result == null ? null : Map<String, dynamic>.from(result),
      );
    } on PostgrestException catch (e) {
      return _SectionLoadResult<Map<String, dynamic>?>(
        errorMessage: _buildSectionErrorMessage(e, 'interview section'),
      );
    } on TimeoutException {
      return const _SectionLoadResult<Map<String, dynamic>?>(
        errorMessage: 'Request timed out while loading interview section.',
      );
    } catch (e) {
      return _SectionLoadResult<Map<String, dynamic>?>(
        errorMessage: e.toString().replaceFirst(
          'Exception: ',
          'Failed loading interview data: ',
        ),
      );
    }
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

  String _docLabel(String? type) {
    switch ((type ?? '').trim().toLowerCase()) {
      case 'income_certificate':
        return 'Tax Exemption Certificate (PDF)';
      case 'applicant_photo':
        return 'Applicant 1x1 Photo';
      default:
        return _statusLabel(type);
    }
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

  bool _isEditableApplication() {
    final app = _application;
    if (app == null) return false;
    final status = (app['status'] ?? '').toString().trim().toLowerCase();
    final isLocked = app['is_locked'] == true;
    return !isLocked &&
        <String>{'draft', 'returned_for_correction'}.contains(status);
  }

  List<({String label, String when})> _buildTimeline() {
    if (_application == null) return const [];
    final app = _application!;
    final events = <({String label, String when})>[
      (label: 'Draft created', when: _formatDateTime(app['created_at'])),
    ];
    if ((app['submitted_at'] ?? '').toString().isNotEmpty) {
      events.add((
        label: 'Application submitted',
        when: _formatDateTime(app['submitted_at']),
      ));
    }
    if (_examRecord != null &&
        (_examRecord?['updated_at'] ?? '').toString().isNotEmpty) {
      events.add((
        label:
            'Exam result: ${_statusLabel(_examRecord?['result']?.toString())}',
        when: _formatDateTime(_examRecord?['updated_at']),
      ));
    }
    if (_interviewRecord != null &&
        (_interviewRecord?['scheduled_at'] ?? '').toString().isNotEmpty) {
      events.add((
        label: 'Interview scheduled',
        when: _formatDateTime(_interviewRecord?['scheduled_at']),
      ));
    }
    if ((app['updated_at'] ?? '').toString().isNotEmpty) {
      events.add((
        label: 'Current status: ${_statusLabel(app['status']?.toString())}',
        when: _formatDateTime(app['updated_at']),
      ));
    }
    return events;
  }

  Widget _sectionError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFFEAB4B4)),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.danger)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Application Detail')),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: EmptyState(
            title: 'Unable to load application',
            message: _errorMessage!,
            actionLabel: 'Retry',
            onAction: _loadApplication,
          ),
        ),
      );
    }

    if (_application == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Application Detail')),
        body: const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: EmptyState(
            title: 'No record found',
            message:
                'This application does not exist or you do not have access to it.',
          ),
        ),
      );
    }

    final app = _application!;
    final appId = (app['id'] ?? '').toString();
    final remarks = (app['secretary_remarks'] ?? '').toString().trim();
    final canEdit = _isEditableApplication();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadApplication,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppHeader(
                title: 'Application Tracking',
                subtitle: (app['application_no'] ?? '-').toString(),
                leading: IconButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/applications');
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                trailing: IconButton(
                  onPressed: canEdit && appId.trim().isNotEmpty
                      ? () => context.push('/applications/$appId/edit')
                      : null,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                child: Column(
                  children: [
                    InfoRow(
                      label: 'Program',
                      value: (app['scholarship_type'] ?? '-').toString(),
                      emphasize: true,
                    ),
                    InfoRow(
                      label: 'School Year',
                      value: (app['school_year'] ?? '-').toString(),
                    ),
                    Row(
                      children: [
                        const Text('Status'),
                        const Spacer(),
                        StatusBadge(
                          text: _statusLabel(app['status']?.toString()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (remarks.isNotEmpty)
                SectionCard(
                  title: 'Correction / Remarks',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E6),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      remarks,
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (remarks.isNotEmpty) const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Exam Result',
                child: _examError != null
                    ? _sectionError(_examError!)
                    : (_examRecord == null
                          ? const Text('No exam record available yet.')
                          : Column(
                              children: [
                                InfoRow(
                                  label: 'Control No.',
                                  value:
                                      (_examRecord?['exam_control_no'] ?? '-')
                                          .toString(),
                                ),
                                InfoRow(
                                  label: 'Raw Score',
                                  value: (_examRecord?['raw_score'] ?? '-')
                                      .toString(),
                                ),
                                InfoRow(
                                  label: 'Percentage',
                                  value:
                                      (_examRecord?['percentage_score'] ?? '-')
                                          .toString(),
                                ),
                                Row(
                                  children: [
                                    const Text('Result'),
                                    const Spacer(),
                                    StatusBadge(
                                      text: _statusLabel(
                                        _examRecord?['result']?.toString(),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Interview Schedule',
                child: _interviewError != null
                    ? _sectionError(_interviewError!)
                    : (_interviewRecord == null
                          ? const Text('Interview is not yet scheduled.')
                          : Column(
                              children: [
                                InfoRow(
                                  label: 'Date',
                                  value: _formatDateTime(
                                    _interviewRecord?['scheduled_at'],
                                  ),
                                ),
                                InfoRow(
                                  label: 'Venue',
                                  value: (_interviewRecord?['venue'] ?? '-')
                                      .toString(),
                                ),
                                Row(
                                  children: [
                                    const Text('Status'),
                                    const Spacer(),
                                    StatusBadge(
                                      text: _statusLabel(
                                        _interviewRecord?['status']?.toString(),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Requirement Checklist',
                child: _documentsError != null
                    ? _sectionError(_documentsError!)
                    : (_documents.isEmpty
                          ? const Text('No uploaded requirement documents yet.')
                          : Column(
                              children: _documents
                                  .map(
                                    (d) => RequirementItem(
                                      label: _docLabel(
                                        d['document_type']?.toString(),
                                      ),
                                      status: _docStatusLabel(
                                        d['verification_status']?.toString(),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            )),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                title: 'Application Timeline',
                child: TimelineList(items: _buildTimeline()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLoadResult<T> {
  const _SectionLoadResult({this.data, this.errorMessage});
  final T? data;
  final String? errorMessage;
}
