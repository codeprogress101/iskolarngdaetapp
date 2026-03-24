import 'package:supabase_flutter/supabase_flutter.dart';

class FeaturePolicySnapshot {
  const FeaturePolicySnapshot({
    required this.applicationIntakeOpen,
    required this.applicationIntakeReason,
    required this.applicationOpenDate,
    required this.applicationCloseDate,
    required this.registrationEnabled,
    required this.registrationSchemaWarning,
    required this.workflowControls,
  });

  final bool applicationIntakeOpen;
  final String applicationIntakeReason;
  final DateTime? applicationOpenDate;
  final DateTime? applicationCloseDate;
  final bool registrationEnabled;
  final String? registrationSchemaWarning;
  final Map<String, dynamic> workflowControls;

  String intakeClosedMessage() {
    if (applicationIntakeReason == 'before_open_date' &&
        applicationOpenDate != null) {
      return 'New application filing opens on ${_formatDate(applicationOpenDate!)}.';
    }
    if (applicationIntakeReason == 'after_close_date' &&
        applicationCloseDate != null) {
      return 'New application filing closed on ${_formatDate(applicationCloseDate!)}.';
    }
    if (applicationIntakeReason == 'closed_by_admin') {
      return 'New application filing is currently turned OFF by System Administrator.';
    }
    if (applicationIntakeReason == 'policy_check_failed') {
      return 'New application filing is temporarily unavailable. Please try again later.';
    }
    return 'New application filing is currently closed by System Administrator.';
  }

  String _formatDate(DateTime value) {
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
    final local = value.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }
}

class FeaturePolicyService {
  FeaturePolicyService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<FeaturePolicySnapshot> fetchSnapshot() async {
    final controls = await _fetchWorkflowControls();
    final intake = await _fetchApplicationIntakePolicy();
    final registration = await _fetchRegistrationPolicy(
      controls: controls.data,
      controlsWarning: controls.errorMessage,
    );

    return FeaturePolicySnapshot(
      applicationIntakeOpen: intake.isOpen,
      applicationIntakeReason: intake.reason,
      applicationOpenDate: intake.openDate,
      applicationCloseDate: intake.closeDate,
      registrationEnabled: registration.enabled,
      registrationSchemaWarning: registration.schemaWarning,
      workflowControls: controls.data ?? const <String, dynamic>{},
    );
  }

  Future<_SectionLoadResult<Map<String, dynamic>>>
  _fetchWorkflowControls() async {
    try {
      final response = await _supabase.rpc('active_workflow_controls');
      if (response is Map<String, dynamic>) {
        return _SectionLoadResult<Map<String, dynamic>>(data: response);
      }
      if (response is List && response.isNotEmpty) {
        final first = response.first;
        if (first is Map<String, dynamic>) {
          return _SectionLoadResult<Map<String, dynamic>>(data: first);
        }
      }
      return const _SectionLoadResult<Map<String, dynamic>>(
        data: <String, dynamic>{},
        errorMessage:
            'Schema mismatch: invalid `active_workflow_controls` RPC response type.',
      );
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      final missingRpc =
          message.contains('active_workflow_controls') &&
          (message.contains('does not exist') || message.contains('function'));
      if (missingRpc) {
        return const _SectionLoadResult<Map<String, dynamic>>(
          data: <String, dynamic>{},
          errorMessage:
              'Schema mismatch: missing RPC `active_workflow_controls`.',
        );
      }
      return _SectionLoadResult<Map<String, dynamic>>(
        data: const <String, dynamic>{},
        errorMessage: 'Workflow controls check failed: ${e.message}',
      );
    } catch (e) {
      return _SectionLoadResult<Map<String, dynamic>>(
        data: const <String, dynamic>{},
        errorMessage:
            'Workflow controls check failed: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<_ApplicationIntakePolicy> _fetchApplicationIntakePolicy() async {
    try {
      final response = await _supabase.rpc('application_intake_is_open');
      final map = _extractPolicyMap(response);
      if (map == null) {
        return const _ApplicationIntakePolicy(
          isOpen: false,
          reason: 'policy_check_failed',
          openDate: null,
          closeDate: null,
        );
      }
      final isOpen = map['is_open'] != false;
      final reason = (map['reason'] ?? 'open').toString();
      return _ApplicationIntakePolicy(
        isOpen: isOpen,
        reason: reason,
        openDate: _toDate(map['open_date']),
        closeDate: _toDate(map['close_date']),
      );
    } catch (_) {
      return const _ApplicationIntakePolicy(
        isOpen: false,
        reason: 'policy_check_failed',
        openDate: null,
        closeDate: null,
      );
    }
  }

  Map<String, dynamic>? _extractPolicyMap(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response;
    }
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
    }
    return null;
  }

  DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    return parsed;
  }

  Future<_RegistrationPolicy> _fetchRegistrationPolicy({
    required Map<String, dynamic>? controls,
    required String? controlsWarning,
  }) async {
    if (controls != null && controls.containsKey('registration_enabled')) {
      final value = controls['registration_enabled'];
      return _RegistrationPolicy(
        enabled: value is bool
            ? value
            : value.toString().toLowerCase() == 'true',
        schemaWarning: controlsWarning,
      );
    }

    try {
      final row = await _supabase
          .from('ranking_settings')
          .select('ranking_basis')
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) {
        return _RegistrationPolicy(
          enabled: false,
          schemaWarning:
              controlsWarning ??
              'Registration policy check failed: no active `ranking_settings` row found.',
        );
      }

      final rankingBasis = row['ranking_basis'];
      if (rankingBasis is! Map<String, dynamic>) {
        return _RegistrationPolicy(
          enabled: false,
          schemaWarning:
              controlsWarning ??
              'Schema mismatch: `ranking_settings.ranking_basis` is not a JSON object.',
        );
      }
      final rankingControls = rankingBasis['controls'];
      if (rankingControls is! Map<String, dynamic>) {
        return _RegistrationPolicy(
          enabled: false,
          schemaWarning:
              controlsWarning ??
              'Schema mismatch: missing JSON object `ranking_settings.ranking_basis.controls`.',
        );
      }
      if (!rankingControls.containsKey('registration_enabled')) {
        return _RegistrationPolicy(
          enabled: false,
          schemaWarning:
              controlsWarning ??
              'Schema mismatch: missing key `ranking_settings.ranking_basis.controls.registration_enabled`.',
        );
      }

      final value = rankingControls['registration_enabled'];
      if (value is bool) {
        return _RegistrationPolicy(
          enabled: value,
          schemaWarning: controlsWarning,
        );
      }
      return _RegistrationPolicy(
        enabled: value.toString().toLowerCase() == 'true',
        schemaWarning: controlsWarning,
      );
    } on PostgrestException catch (e) {
      final message = e.message;
      final relationMatch = RegExp(
        r'relation\s+"?([a-zA-Z0-9_]+)"?\s+does not exist',
        caseSensitive: false,
      ).firstMatch(message);
      if (relationMatch != null) {
        return _RegistrationPolicy(
          enabled: false,
          schemaWarning:
              controlsWarning ??
              'Schema mismatch: missing table `${relationMatch.group(1)}`.',
        );
      }
      return _RegistrationPolicy(
        enabled: false,
        schemaWarning:
            controlsWarning ??
            'Registration policy check failed: ${e.message}.',
      );
    } catch (e) {
      return _RegistrationPolicy(
        enabled: false,
        schemaWarning:
            controlsWarning ??
            'Registration policy check failed: ${e.toString().replaceFirst('Exception: ', '')}.',
      );
    }
  }
}

class _ApplicationIntakePolicy {
  const _ApplicationIntakePolicy({
    required this.isOpen,
    required this.reason,
    required this.openDate,
    required this.closeDate,
  });

  final bool isOpen;
  final String reason;
  final DateTime? openDate;
  final DateTime? closeDate;
}

class _RegistrationPolicy {
  const _RegistrationPolicy({
    required this.enabled,
    required this.schemaWarning,
  });

  final bool enabled;
  final String? schemaWarning;
}

class _SectionLoadResult<T> {
  const _SectionLoadResult({this.data, this.errorMessage});

  final T? data;
  final String? errorMessage;
}
