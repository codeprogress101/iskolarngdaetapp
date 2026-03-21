import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ui/components/app_components.dart';
import '../../ui/theme/app_theme.dart';

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upperText = newValue.text.toUpperCase();
    return newValue.copyWith(text: upperText);
  }
}

class ApplicationEditPage extends StatefulWidget {
  const ApplicationEditPage({required this.appId, super.key});
  final String appId;

  @override
  State<ApplicationEditPage> createState() => _ApplicationEditPageState();
}

class _ApplicationEditPageState extends State<ApplicationEditPage> {
  static const List<String> _editableStatuses = <String>[
    'draft',
    'returned_for_correction',
  ];

  static const String _storageBucket = 'ldss-documents';
  static const int _maxFileSizeBytes = 10 * 1024 * 1024;

  final SupabaseClient _supabase = Supabase.instance.client;
  late final bool _isCreateMode;

  bool _isLoading = true;
  bool _saving = false;
  String? _errorMessage;
  String? _statusMessage;
  bool _statusIsError = false;
  bool _auxDataTableAvailable = true;
  bool _profilesSupportsPlaceOfBirth = true;
  Map<String, dynamic>? _application;
  String _municipality = 'DAET';
  List<String> _barangayOptions = <String>['SELECT BARANGAY'];
  String _selectedBarangay = 'SELECT BARANGAY';
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;
  String? _selectedPhotoExtension;
  String? _storedPhotoPath;
  String? _storedPhotoUrl;

  late final TextEditingController _applicationNo;
  late final TextEditingController _lastName;
  late final TextEditingController _firstName;
  late final TextEditingController _middleName;
  late final TextEditingController _birthDate;
  late final TextEditingController _placeOfBirth;
  late final TextEditingController _barangay;
  late final TextEditingController _addressLine;
  late final TextEditingController _contact;
  late final TextEditingController _email;
  late final TextEditingController _schoolName;
  late final TextEditingController _degreeCourse;
  late final TextEditingController _gwa;
  late final TextEditingController _fatherFirstName;
  late final TextEditingController _fatherMiddleName;
  late final TextEditingController _fatherLastName;
  late final TextEditingController _motherFirstName;
  late final TextEditingController _motherMiddleName;
  late final TextEditingController _motherMaidenName;
  late final TextEditingController _fatherAddress;
  late final TextEditingController _motherAddress;
  late final TextEditingController _fatherOccupation;
  late final TextEditingController _motherOccupation;
  late final TextEditingController _fatherEducation;
  late final TextEditingController _motherEducation;
  late final TextEditingController _income;
  late final TextEditingController _childrenInFamily;
  late final TextEditingController _brotherCount;
  late final TextEditingController _sisterCount;
  late final TextEditingController _spouseName;
  late final TextEditingController _spouseChildrenCount;
  late final TextEditingController _spouseOccupation;
  late final TextEditingController _awardNatureDescription;
  late final TextEditingController _awardSchoolName;
  late final TextEditingController _awardYearAwarded;

  String _schoolYear = '2025-2026';
  String _applicantCategory = 'NEW APPLICANT';
  String _grantAppliedFor = 'DEGREE COURSE';
  String _sex = 'Male';
  String _civilStatus = 'Single';
  String _religion = 'ROMAN CATHOLIC';
  String _sectorClassification = 'None of the above';
  String _highestEducationAttainment = 'SELECT';
  String _highestGradeYearLevel = 'SELECT';
  String _schoolType = 'PUBLIC';
  String _fatherStatus = 'Alive';
  String _motherStatus = 'Alive';
  bool _agreementChecked = true;
  bool _privacyChecked = true;
  int _currentStep = 0;
  bool _autoSaving = false;
  DateTime? _lastAutoSavedAt;
  String? _autoSaveError;
  bool _showSavePulse = false;
  int _savePulseTick = 0;

  static const List<String> _stepLabels = <String>[
    'Setup',
    'Personal',
    'Awards',
    'Address',
    'Family',
    'Married',
    'Review',
  ];

  final List<Map<String, String>> _awards = <Map<String, String>>[];
  static const double _formSpacing = 14;
  static const double _formRunSpacing = 12;

  @override
  void initState() {
    super.initState();
    _isCreateMode = widget.appId.trim().toLowerCase() == 'new';
    _applicationNo = TextEditingController();
    _lastName = TextEditingController();
    _firstName = TextEditingController();
    _middleName = TextEditingController();
    _birthDate = TextEditingController();
    _placeOfBirth = TextEditingController();
    _barangay = TextEditingController();
    _addressLine = TextEditingController();
    _contact = TextEditingController();
    _email = TextEditingController();
    _schoolName = TextEditingController();
    _degreeCourse = TextEditingController();
    _gwa = TextEditingController();
    _fatherFirstName = TextEditingController();
    _fatherMiddleName = TextEditingController();
    _fatherLastName = TextEditingController();
    _motherFirstName = TextEditingController();
    _motherMiddleName = TextEditingController();
    _motherMaidenName = TextEditingController();
    _fatherAddress = TextEditingController();
    _motherAddress = TextEditingController();
    _fatherOccupation = TextEditingController();
    _motherOccupation = TextEditingController();
    _fatherEducation = TextEditingController();
    _motherEducation = TextEditingController();
    _income = TextEditingController();
    _childrenInFamily = TextEditingController();
    _brotherCount = TextEditingController();
    _sisterCount = TextEditingController();
    _spouseName = TextEditingController();
    _spouseChildrenCount = TextEditingController();
    _spouseOccupation = TextEditingController();
    _awardNatureDescription = TextEditingController();
    _awardSchoolName = TextEditingController();
    _awardYearAwarded = TextEditingController();
    _loadBarangayOptions();
    _load();
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _applicationNo,
      _lastName,
      _firstName,
      _middleName,
      _birthDate,
      _placeOfBirth,
      _barangay,
      _addressLine,
      _contact,
      _email,
      _schoolName,
      _degreeCourse,
      _gwa,
      _fatherFirstName,
      _fatherMiddleName,
      _fatherLastName,
      _motherFirstName,
      _motherMiddleName,
      _motherMaidenName,
      _fatherAddress,
      _motherAddress,
      _fatherOccupation,
      _motherOccupation,
      _fatherEducation,
      _motherEducation,
      _income,
      _childrenInFamily,
      _brotherCount,
      _sisterCount,
      _spouseName,
      _spouseChildrenCount,
      _spouseOccupation,
      _awardNatureDescription,
      _awardSchoolName,
      _awardYearAwarded,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated applicant session found.');
      }

      Map<String, dynamic>? profile;
      try {
        profile = await _supabase
            .from('profiles')
            .select(_profileSelectFields())
            .eq('id', user.id)
            .maybeSingle();
      } on PostgrestException catch (e) {
        if (_profilesSupportsPlaceOfBirth &&
            e.message.toLowerCase().contains('place_of_birth')) {
          _profilesSupportsPlaceOfBirth = false;
          profile = await _supabase
              .from('profiles')
              .select(_profileSelectFields())
              .eq('id', user.id)
              .maybeSingle();
        } else {
          rethrow;
        }
      }

      Map<String, dynamic>? app;
      if (_isCreateMode) {
        app = <String, dynamic>{
          'id': null,
          'application_no': '',
          'application_type': 'new',
          'scholarship_type': 'Revised Daet Expanded Scholarship Program',
          'school_year': _schoolYear,
          'sector_classification': _sectorClassification,
          'status': 'draft',
          'submitted_at': null,
          'is_locked': false,
          'created_at': null,
          'updated_at': null,
        };
      } else {
        app = await _supabase
            .from('applications')
            .select(
              'id, application_no, application_type, scholarship_type, school_year, sector_classification, status, submitted_at, is_locked, created_at, updated_at',
            )
            .eq('id', widget.appId)
            .eq('applicant_id', user.id)
            .maybeSingle();
      }

      if (!mounted) return;
      setState(() {
        _application = app == null ? null : Map<String, dynamic>.from(app);
      });

      if (_application != null) {
        _applicationNo.text = (_application!['application_no'] ?? '')
            .toString();
        _schoolYear = (_application!['school_year'] ?? _schoolYear).toString();
        _grantAppliedFor = 'DEGREE COURSE';
        final type = (_application!['application_type'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        _applicantCategory = type == 'renewal'
            ? 'RENEWAL (TEMPORARILY DISABLED)'
            : 'NEW APPLICANT';
        _sectorClassification =
            (_application!['sector_classification'] ?? _sectorClassification)
                .toString();
      }

      if (profile != null) {
        _lastName.text = (profile['last_name'] ?? '').toString();
        _firstName.text = (profile['first_name'] ?? '').toString();
        _middleName.text = (profile['middle_name'] ?? '').toString();
        _sex = (profile['sex'] ?? _sex).toString();
        _civilStatus = (profile['civil_status'] ?? _civilStatus).toString();
        _birthDate.text = (profile['date_of_birth'] ?? '').toString();
        _placeOfBirth.text = (profile['place_of_birth'] ?? '').toString();
        final normalizedAddress = _normalizeAddressFields(
          rawAddress: (profile['address'] ?? '').toString(),
          rawBarangay: (profile['barangay'] ?? '').toString(),
        );
        _applyBarangayFromValue(normalizedAddress['barangay'] ?? '');
        _addressLine.text = normalizedAddress['addressLine'] ?? '';
        _contact.text = _mobileForInput(
          (profile['mobile_number'] ?? '').toString(),
        );
        _email.text = (profile['email'] ?? user.email ?? '')
            .toString()
            .toLowerCase();
        _schoolName.text = (profile['school_name'] ?? '').toString();
        _degreeCourse.text = (profile['course_or_strand'] ?? '').toString();
        _highestGradeYearLevel =
            (profile['year_level'] ?? _highestGradeYearLevel).toString();
        _storedPhotoPath = (profile['applicant_photo_path'] ?? '').toString();
        await _loadStoredPhotoPreview(_storedPhotoPath ?? '');
      }

      final appId = (_application?['id'] ?? '').toString();
      if (appId.isNotEmpty) {
        await _hydrateAux(user.id, appId);
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _dbErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _profileSelectFields() {
    const base =
        'first_name, middle_name, last_name, sex, civil_status, date_of_birth, barangay, address, mobile_number, email, school_name, course_or_strand, year_level, guardian_name, guardian_occupation, monthly_income, applicant_photo_path';
    if (_profilesSupportsPlaceOfBirth) return '$base, place_of_birth';
    return base;
  }

  Future<void> _loadBarangayOptions() async {
    try {
      final content = await rootBundle.loadString(
        'assets/reference/daet_barangays.txt',
      );
      final parsed = content
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _barangayOptions = <String>['SELECT BARANGAY', ...parsed];
        if (_selectedBarangay != 'SELECT BARANGAY' &&
            !_barangayOptions.contains(_selectedBarangay)) {
          _barangayOptions.add(_selectedBarangay);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Barangay list file is missing (`assets/reference/daet_barangays.txt`).';
        _statusIsError = true;
      });
    }
  }

  void _applyBarangayFromValue(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      _selectedBarangay = 'SELECT BARANGAY';
      _barangay.text = '';
      return;
    }
    final matched = _barangayOptions.firstWhere(
      (option) => option.toUpperCase() == value.toUpperCase(),
      orElse: () => value.toUpperCase(),
    );
    if (!_barangayOptions.contains(matched)) {
      _barangayOptions.add(matched);
    }
    _selectedBarangay = matched;
    _barangay.text = matched;
  }

  String _payloadText(Map<String, dynamic> payload, String key) {
    final raw = payload[key];
    if (raw == null) return '';
    final text = raw.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _sanitizeText(String value) {
    var text = value.trim();
    if (text.isEmpty) return '';
    text = text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript\s*:', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bon\w+\s*=', caseSensitive: false), '')
        .replaceAll('\u0000', '')
        .trim();
    return text;
  }

  String _safeUpper(String value) => _sanitizeText(value).toUpperCase();

  String _safeLower(String value) => _sanitizeText(value).toLowerCase();

  String _safeNumericText(String value) {
    final sanitized = _sanitizeText(value).replaceAll(',', '');
    return sanitized.replaceAll(RegExp(r'[^0-9.]'), '');
  }

  String _normalizeParentStatus(String value, String fallback) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'deceased') return 'Deceased';
    if (normalized == 'alive') return 'Alive';
    return fallback;
  }

  bool _isEditable() {
    final app = _application;
    if (app == null) return false;
    final status = (app['status'] ?? '').toString().toLowerCase().trim();
    return app['is_locked'] != true && _editableStatuses.contains(status);
  }

  String _mobileForInput(String value) {
    final raw = value.trim();
    if (RegExp(r'^\+639\d{9}$').hasMatch(raw)) return '0${raw.substring(3)}';
    return raw;
  }

  String _normalizeMobileForStorage(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';
    final cleaned = raw.replaceAll(RegExp(r'[\s()-]'), '');
    final digits = cleaned.replaceAll(RegExp(r'\D'), '');
    if (RegExp(r'^09\d{9}$').hasMatch(digits)) {
      return '+63${digits.substring(1)}';
    }
    if (RegExp(r'^9\d{9}$').hasMatch(digits)) return '+63$digits';
    if (RegExp(r'^63\d{10}$').hasMatch(digits)) return '+$digits';
    return raw;
  }

  Map<String, String> _normalizeAddressFields({
    required String rawAddress,
    required String rawBarangay,
  }) {
    final sourceAddress = rawAddress.trim();
    var normalizedBarangay = rawBarangay.trim();
    if (sourceAddress.isEmpty) {
      return <String, String>{
        'addressLine': '',
        'barangay': normalizedBarangay,
      };
    }

    final segments = sourceAddress
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return <String, String>{
        'addressLine': sourceAddress,
        'barangay': normalizedBarangay,
      };
    }

    final cleaned = List<String>.from(segments);
    while (cleaned.isNotEmpty && _isMunicipalitySegment(cleaned.last)) {
      cleaned.removeLast();
    }

    if (cleaned.length >= 2) {
      final candidateBarangay = cleaned.last.trim();
      if (_looksLikeBarangay(candidateBarangay) ||
          normalizedBarangay.isEmpty ||
          candidateBarangay.toUpperCase() == normalizedBarangay.toUpperCase()) {
        normalizedBarangay = candidateBarangay;
        cleaned.removeLast();
      }
    }

    if (cleaned.length == 1 &&
        normalizedBarangay.isNotEmpty &&
        cleaned.first.toUpperCase() == normalizedBarangay.toUpperCase()) {
      cleaned.clear();
    }

    return <String, String>{
      'addressLine': cleaned.join(', '),
      'barangay': normalizedBarangay,
    };
  }

  bool _looksLikeBarangay(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) return false;
    if (normalized.contains('BARANGAY') ||
        normalized.contains('BRGY') ||
        normalized.contains('BRGY')) {
      return true;
    }
    return _barangayOptions.any(
      (option) =>
          option != 'SELECT BARANGAY' &&
          option.trim().toUpperCase() == normalized,
    );
  }

  bool _isMunicipalitySegment(String value) {
    final normalized = value
        .trim()
        .toUpperCase()
        .replaceAll('.', '')
        .replaceAll(RegExp(r'\s+'), ' ');
    return normalized == 'DAET' ||
        normalized == 'MUNICIPALITY OF DAET' ||
        normalized == 'CAMARINES NORTE' ||
        normalized == 'DAET CAMARINES NORTE' ||
        normalized == 'PHILIPPINES';
  }

  String _composeAddressForStorage() {
    final addressLine = _safeUpper(_addressLine.text);
    final barangay = _safeUpper(_barangay.text);
    final segments = <String>[];
    if (addressLine.isNotEmpty) segments.add(addressLine);
    if (barangay.isNotEmpty) segments.add(barangay);
    segments.add(_municipality.toUpperCase());
    return segments.join(', ');
  }

  String _dbErrorMessage(PostgrestException e) {
    final m = e.message;
    final c = RegExp(
      r'column\s+([a-zA-Z0-9_]+\.[a-zA-Z0-9_]+)\s+does not exist',
      caseSensitive: false,
    ).firstMatch(m);
    final r = RegExp(
      r'relation\s+"?([a-zA-Z0-9_]+)"?\s+does not exist',
      caseSensitive: false,
    ).firstMatch(m);
    if (c != null) return 'Schema mismatch: missing column `${c.group(1)}`.';
    if (r != null) return 'Schema mismatch: missing table `${r.group(1)}`.';
    return 'Database operation failed. Please try again.';
  }

  Future<void> _loadStoredPhotoPreview(String storagePath) async {
    if (storagePath.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _storedPhotoUrl = null;
      });
      return;
    }
    try {
      final signedUrl = await _supabase.storage
          .from(_storageBucket)
          .createSignedUrl(storagePath, 60 * 60);
      if (!mounted) return;
      setState(() {
        _storedPhotoUrl = signedUrl;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _storedPhotoUrl = null;
      });
    }
  }

  Future<void> _pickApplicantPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: const <String>['jpg', 'jpeg', 'png'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _statusMessage = 'Failed to read selected image.';
          _statusIsError = true;
        });
        return;
      }

      if (bytes.length > _maxFileSizeBytes) {
        setState(() {
          _statusMessage = 'Applicant 1x1 photo exceeds 10MB limit.';
          _statusIsError = true;
        });
        return;
      }

      final ext = (file.extension ?? 'jpg').toLowerCase();
      setState(() {
        _selectedPhotoBytes = bytes;
        _selectedPhotoName = file.name;
        _selectedPhotoExtension = ext;
        _statusMessage =
            'Selected applicant photo: ${file.name} (${(bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB)';
        _statusIsError = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage =
            'Failed to pick applicant photo: ${e.toString().replaceFirst('Exception: ', '')}';
        _statusIsError = true;
      });
    }
  }

  Future<void> _uploadApplicantPhotoIfNeeded({
    required String userId,
    required String applicationId,
  }) async {
    if (_selectedPhotoBytes == null) return;

    final ext = (_selectedPhotoExtension ?? 'jpg').toLowerCase();
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    final path =
        'applicant-photos/$userId/$applicationId-${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _supabase.storage
        .from(_storageBucket)
        .uploadBinary(
          path,
          _selectedPhotoBytes!,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    _storedPhotoPath = path;
    await _loadStoredPhotoPreview(path);

    await _supabase
        .from('profiles')
        .update(<String, dynamic>{'applicant_photo_path': path})
        .eq('id', userId);

    final existingDocs = await _supabase
        .from('application_documents')
        .select('id, storage_path')
        .eq('application_id', applicationId)
        .eq('document_type', 'applicant_photo')
        .order('created_at', ascending: false)
        .limit(1);

    final payload = <String, dynamic>{
      'application_id': applicationId,
      'document_type': 'applicant_photo',
      'storage_path': path,
      'original_filename': _selectedPhotoName ?? 'applicant-photo.$ext',
      'mime_type': contentType,
      'file_size_bytes': _selectedPhotoBytes!.length,
      'verification_status': 'pending',
      'verification_notes': null,
      'uploaded_by': userId,
    };

    final docs = List<Map<String, dynamic>>.from(existingDocs as List);
    if (docs.isNotEmpty) {
      await _supabase
          .from('application_documents')
          .update(payload)
          .eq('id', docs.first['id']);
    } else {
      await _supabase.from('application_documents').insert(payload);
    }
  }

  List<String> _validate({required bool submitting}) {
    final errors = <String>[];
    void required(String label, String value) {
      final normalized = value.trim().toUpperCase();
      if (normalized.isEmpty || normalized == 'SELECT') {
        errors.add(
          '$label is required${submitting ? ' before submission' : ''}.',
        );
      }
    }

    if (submitting) {
      required('School Year', _schoolYear);
      required('Last Name', _lastName.text);
      required('First Name', _firstName.text);
      required('Gender', _sex);
      required('Status', _civilStatus);
      required('Religion', _religion);
      required('Date of Birth', _birthDate.text);
      required('Place of Birth', _placeOfBirth.text);
      required('Sector Classification', _sectorClassification);
      required('Contact Number', _contact.text);
      required('Email Address', _email.text);
      required('Highest Educational Attainment', _highestEducationAttainment);
      required('Highest Grade/Year', _highestGradeYearLevel);
      required('General Weighted Average', _gwa.text);
      required('School Name', _schoolName.text);
      required('School Type', _schoolType);
      required('Grant Applied For', _grantAppliedFor);
      required('Degree Course', _degreeCourse.text);
      required('Father First Name', _fatherFirstName.text);
      required('Father Middle Name', _fatherMiddleName.text);
      required('Father Surname', _fatherLastName.text);
      required('Mother First Name', _motherFirstName.text);
      required('Mother Middle Name', _motherMiddleName.text);
      required('Mother Maiden Name', _motherMaidenName.text);
      required('Father Address', _fatherAddress.text);
      required('Mother Address', _motherAddress.text);
      required('Father Occupation', _fatherOccupation.text);
      required('Mother Occupation', _motherOccupation.text);
      required('Father Educational Attainment', _fatherEducation.text);
      required('Mother Educational Attainment', _motherEducation.text);
      required('Total Parents Gross Income', _income.text);
      required('No. of Children in Family', _childrenInFamily.text);
      required('No. of Brothers', _brotherCount.text);
      required('No. of Sisters', _sisterCount.text);
      required('Barangay', _selectedBarangay);
    }

    if (_selectedBarangay.toUpperCase() == 'SELECT BARANGAY') {
      if (submitting) {
        errors.add('Barangay is required before submission.');
      }
    }
    if (submitting &&
        _selectedPhotoBytes == null &&
        (_storedPhotoPath ?? '').trim().isEmpty) {
      errors.add('Applicant 1x1 Photo is required before submission.');
    }

    final mobile = _normalizeMobileForStorage(_contact.text);
    if (mobile.isNotEmpty && !RegExp(r'^\+?\d{10,15}$').hasMatch(mobile)) {
      errors.add('Contact Number is invalid.');
    }
    if (_email.text.trim().isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      errors.add('Email Address is invalid.');
    }
    final gwaInput = _gwa.text.replaceAll('%', '').trim();
    final gwa = double.tryParse(gwaInput);
    if ((submitting || gwaInput.isNotEmpty) &&
        (gwa == null || gwa < 0 || gwa > 100)) {
      errors.add(
        'General Weighted Average must be a number between 0 and 100.',
      );
    }

    int? parseCount(String value) {
      final v = value.trim();
      if (v.isEmpty) return null;
      return int.tryParse(v);
    }

    final children = parseCount(_childrenInFamily.text);
    final brothers = parseCount(_brotherCount.text);
    final sisters = parseCount(_sisterCount.text);
    final spouseChildren = parseCount(_spouseChildrenCount.text);
    final income = double.tryParse(_income.text.trim().replaceAll(',', ''));

    if (_childrenInFamily.text.trim().isNotEmpty &&
        (children == null || children < 0)) {
      errors.add('No. of Children in Family must be a non-negative number.');
    }
    if (_brotherCount.text.trim().isNotEmpty &&
        (brothers == null || brothers < 0)) {
      errors.add('No. of Brothers must be a non-negative number.');
    }
    if (_sisterCount.text.trim().isNotEmpty &&
        (sisters == null || sisters < 0)) {
      errors.add('No. of Sisters must be a non-negative number.');
    }
    if (_spouseChildrenCount.text.trim().isNotEmpty &&
        (spouseChildren == null || spouseChildren < 0)) {
      errors.add(
        'No. of Children (spouse section) must be a non-negative number.',
      );
    }
    if (_income.text.trim().isNotEmpty && (income == null || income < 0)) {
      errors.add('Total Parents Gross Income must be a non-negative number.');
    }

    return errors;
  }

  Future<void> _ensureApplicationIntakeIsOpen() async {
    dynamic rpcResponse;
    try {
      rpcResponse = await _supabase.rpc('application_intake_is_open');
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      final missingRpc =
          message.contains('application_intake_is_open') &&
          (message.contains('does not exist') ||
              message.contains('function') ||
              message.contains('42883'));
      if (missingRpc) {
        throw Exception(
          'Schema mismatch: missing RPC `application_intake_is_open`.',
        );
      }
      throw Exception(
        'Failed to verify intake status via `application_intake_is_open`: ${_dbErrorMessage(e)}',
      );
    }

    bool? isOpen;
    if (rpcResponse is bool) {
      isOpen = rpcResponse;
    } else if (rpcResponse is Map<String, dynamic>) {
      final value =
          rpcResponse['application_intake_is_open'] ??
          rpcResponse['is_open'] ??
          rpcResponse['open'];
      if (value is bool) isOpen = value;
    } else if (rpcResponse is List && rpcResponse.isNotEmpty) {
      final first = rpcResponse.first;
      if (first is Map<String, dynamic>) {
        final value =
            first['application_intake_is_open'] ??
            first['is_open'] ??
            first['open'];
        if (value is bool) isOpen = value;
      }
    }

    if (isOpen == null) {
      throw Exception(
        'Unable to read intake status from `application_intake_is_open` RPC response.',
      );
    }
    if (!isOpen) {
      throw Exception(
        'Application intake is currently closed. Please try again once intake reopens.',
      );
    }
  }

  Map<String, dynamic> _profilePayload() {
    final income = double.tryParse(_safeNumericText(_income.text));
    final guardianName = [
      _fatherFirstName.text,
      _fatherMiddleName.text,
      _fatherLastName.text,
    ].map(_safeUpper).where((e) => e.isNotEmpty).join(' ');

    final payload = <String, dynamic>{
      'first_name': _safeUpper(_firstName.text),
      'middle_name': _sanitizeText(_middleName.text).isEmpty
          ? 'N/A'
          : _safeUpper(_middleName.text),
      'last_name': _safeUpper(_lastName.text),
      'sex': _sex,
      'civil_status': _civilStatus,
      'date_of_birth': _sanitizeText(_birthDate.text),
      'place_of_birth': _safeUpper(_placeOfBirth.text),
      'barangay': _safeUpper(_barangay.text),
      'address': _composeAddressForStorage(),
      'mobile_number': _normalizeMobileForStorage(_contact.text),
      'email': _safeLower(_email.text),
      'school_name': _safeUpper(_schoolName.text),
      'course_or_strand': _safeUpper(_degreeCourse.text),
      'year_level': _highestGradeYearLevel,
      'guardian_name': guardianName,
      'guardian_occupation': _safeUpper(_fatherOccupation.text),
      'monthly_income': income,
    };
    if (!_profilesSupportsPlaceOfBirth) payload.remove('place_of_birth');
    return payload;
  }

  Map<String, dynamic> _auxPayload() => <String, dynamic>{
    'religion': _religion,
    'placeOfBirth': _safeUpper(_placeOfBirth.text),
    'additionalData': _sectorClassification,
    'highestEducationAttainment': _highestEducationAttainment,
    'highestGradeYearLevel': _highestGradeYearLevel,
    'schoolType': _schoolType,
    'grantAppliedFor': _grantAppliedFor,
    'awards': _awards,
    'fatherStatus': _fatherStatus,
    'fatherFirstName': _safeUpper(_fatherFirstName.text),
    'fatherMiddleName': _safeUpper(_fatherMiddleName.text),
    'fatherLastName': _safeUpper(_fatherLastName.text),
    'motherStatus': _motherStatus,
    'motherFirstName': _safeUpper(_motherFirstName.text),
    'motherMiddleName': _safeUpper(_motherMiddleName.text),
    'motherMaidenName': _safeUpper(_motherMaidenName.text),
    'fatherAddress': _safeUpper(_fatherAddress.text),
    'motherAddress': _safeUpper(_motherAddress.text),
    'fatherOccupation': _safeUpper(_fatherOccupation.text),
    'fatherEducationAttainment': _sanitizeText(_fatherEducation.text),
    'gwa': _safeNumericText(_gwa.text),
    'motherOccupation': _safeUpper(_motherOccupation.text),
    'motherEducationAttainment': _sanitizeText(_motherEducation.text),
    'totalParentsGrossIncome': _safeNumericText(_income.text),
    'childrenInFamily': _safeNumericText(_childrenInFamily.text),
    'brotherCount': _safeNumericText(_brotherCount.text),
    'sisterCount': _safeNumericText(_sisterCount.text),
    'isMarriedApplicant': _sanitizeText(_spouseName.text).isNotEmpty,
    'spouseName': _safeUpper(_spouseName.text),
    'spouseChildrenCount': _safeNumericText(_spouseChildrenCount.text),
    'spouseOccupation': _safeUpper(_spouseOccupation.text),
    'degreeProgramCourse': _safeUpper(_degreeCourse.text),
  };
  Future<void> _hydrateAux(String userId, String appId) async {
    if (!_auxDataTableAvailable) return;
    try {
      final row = await _supabase
          .from('application_aux_data')
          .select('payload')
          .eq('application_id', appId)
          .maybeSingle();
      if (row == null) return;
      final payload = Map<String, dynamic>.from((row['payload'] ?? {}) as Map);
      if (!mounted) return;
      setState(() {
        _religion = (payload['religion'] ?? _religion).toString().toUpperCase();
        _sectorClassification =
            (payload['additionalData'] ?? _sectorClassification).toString();
        _highestEducationAttainment =
            (payload['highestEducationAttainment'] ??
                    _highestEducationAttainment)
                .toString()
                .toUpperCase();
        _highestGradeYearLevel =
            (payload['highestGradeYearLevel'] ?? _highestGradeYearLevel)
                .toString()
                .toUpperCase();
        _schoolType = (payload['schoolType'] ?? _schoolType).toString();
        _grantAppliedFor = 'DEGREE COURSE';
        _fatherStatus = _normalizeParentStatus(
          _payloadText(payload, 'fatherStatus'),
          _fatherStatus,
        );
        _motherStatus = _normalizeParentStatus(
          _payloadText(payload, 'motherStatus'),
          _motherStatus,
        );

        final placeOfBirth = _payloadText(payload, 'placeOfBirth');
        if (placeOfBirth.isNotEmpty) {
          _placeOfBirth.text = placeOfBirth.toUpperCase();
        }
        final gwa = _payloadText(payload, 'gwa');
        if (gwa.isNotEmpty) _gwa.text = gwa;
        final degree = _payloadText(payload, 'degreeProgramCourse');
        if (degree.isNotEmpty) _degreeCourse.text = degree.toUpperCase();

        _fatherFirstName.text = _payloadText(
          payload,
          'fatherFirstName',
        ).toUpperCase();
        _fatherMiddleName.text = _payloadText(
          payload,
          'fatherMiddleName',
        ).toUpperCase();
        _fatherLastName.text = _payloadText(
          payload,
          'fatherLastName',
        ).toUpperCase();
        _motherFirstName.text = _payloadText(
          payload,
          'motherFirstName',
        ).toUpperCase();
        _motherMiddleName.text = _payloadText(
          payload,
          'motherMiddleName',
        ).toUpperCase();
        _motherMaidenName.text = _payloadText(
          payload,
          'motherMaidenName',
        ).toUpperCase();
        _fatherAddress.text = _payloadText(
          payload,
          'fatherAddress',
        ).toUpperCase();
        _motherAddress.text = _payloadText(
          payload,
          'motherAddress',
        ).toUpperCase();
        _fatherOccupation.text = _payloadText(
          payload,
          'fatherOccupation',
        ).toUpperCase();
        _motherOccupation.text = _payloadText(
          payload,
          'motherOccupation',
        ).toUpperCase();
        _fatherEducation.text = _payloadText(
          payload,
          'fatherEducationAttainment',
        );
        _motherEducation.text = _payloadText(
          payload,
          'motherEducationAttainment',
        );
        _income.text = _payloadText(payload, 'totalParentsGrossIncome');
        _childrenInFamily.text = _payloadText(payload, 'childrenInFamily');
        _brotherCount.text = _payloadText(payload, 'brotherCount');
        _sisterCount.text = _payloadText(payload, 'sisterCount');
        _spouseName.text = _payloadText(payload, 'spouseName').toUpperCase();
        _spouseChildrenCount.text = _payloadText(
          payload,
          'spouseChildrenCount',
        );
        _spouseOccupation.text = _payloadText(
          payload,
          'spouseOccupation',
        ).toUpperCase();

        final awardsRaw = payload['awards'];
        if (awardsRaw is List) {
          _awards
            ..clear()
            ..addAll(
              awardsRaw.whereType<Map>().map((entry) {
                final row = Map<String, dynamic>.from(entry);
                return <String, String>{
                  'natureDescription': _payloadText(row, 'natureDescription'),
                  'schoolName': _payloadText(row, 'schoolName'),
                  'yearAwarded': _payloadText(row, 'yearAwarded'),
                };
              }),
            );
        }
      });
    } on PostgrestException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('application_aux_data') &&
          (m.contains('does not exist') || m.contains('relation'))) {
        _auxDataTableAvailable = false;
      }
    }
  }

  Future<void> _persistAux(String userId, String appId) async {
    if (!_auxDataTableAvailable) return;
    try {
      await _supabase.from('application_aux_data').upsert(<String, dynamic>{
        'application_id': appId,
        'applicant_id': userId,
        'payload': _auxPayload(),
      }, onConflict: 'application_id');
    } on PostgrestException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('application_aux_data') &&
          (m.contains('does not exist') || m.contains('relation'))) {
        _auxDataTableAvailable = false;
        if (!mounted) return;
        setState(() {
          _statusMessage =
              '`application_aux_data` table is missing. Extended fields are not being persisted.';
          _statusIsError = true;
        });
        return;
      }
      rethrow;
    }
  }

  Future<void> _saveProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated applicant session found.');
    }
    final payload = _profilePayload();
    try {
      await _supabase
          .from('profiles')
          .update(payload)
          .eq('id', user.id)
          .select()
          .single();
    } on PostgrestException catch (e) {
      if (_profilesSupportsPlaceOfBirth &&
          e.message.toLowerCase().contains('place_of_birth')) {
        _profilesSupportsPlaceOfBirth = false;
        payload.remove('place_of_birth');
        await _supabase
            .from('profiles')
            .update(payload)
            .eq('id', user.id)
            .select()
            .single();
      } else {
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> _saveOrCreateDraft() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated applicant session found.');
    }

    await _ensureSingleAttemptPerSchoolYear(
      user.id,
      _schoolYear,
      _application?['id']?.toString(),
    );

    final payload = <String, dynamic>{
      'school_year': _schoolYear,
      'scholarship_type': _degreeCourse.text.trim().isEmpty
          ? _grantAppliedFor
          : _degreeCourse.text.trim().toUpperCase(),
      'application_type': _applicantCategory == 'RENEWAL (TEMPORARILY DISABLED)'
          ? 'renewal'
          : 'new',
      'sector_classification': _sectorClassification,
    };

    final existingId = (_application?['id'] ?? '').toString();
    if (existingId.isNotEmpty) {
      if (!_isEditable()) {
        throw Exception('This application is no longer editable.');
      }
      final result = await _supabase
          .from('applications')
          .update(payload)
          .eq('id', existingId)
          .eq('applicant_id', user.id)
          .select(
            'id, application_no, application_type, scholarship_type, school_year, sector_classification, status, submitted_at, is_locked, created_at, updated_at',
          )
          .single();
      _application = Map<String, dynamic>.from(result);
      _applicationNo.text = (_application!['application_no'] ?? '').toString();
      return _application!;
    }

    await _ensureApplicationIntakeIsOpen();

    final result = await _supabase
        .from('applications')
        .insert(<String, dynamic>{
          ...payload,
          'applicant_id': user.id,
          'status': 'draft',
        })
        .select(
          'id, application_no, application_type, scholarship_type, school_year, sector_classification, status, submitted_at, is_locked, created_at, updated_at',
        )
        .single();
    _application = Map<String, dynamic>.from(result);
    _applicationNo.text = (_application!['application_no'] ?? '').toString();
    return _application!;
  }

  Future<void> _ensureSingleAttemptPerSchoolYear(
    String userId,
    String schoolYear,
    String? excludeApplicationId,
  ) async {
    final query = _supabase
        .from('applications')
        .select('id, application_no, school_year')
        .eq('applicant_id', userId)
        .eq('school_year', schoolYear)
        .order('updated_at', ascending: false)
        .limit(5);

    final rows = await query;
    var data = List<Map<String, dynamic>>.from(rows as List);
    if (excludeApplicationId != null && excludeApplicationId.isNotEmpty) {
      data = data
          .where((row) => (row['id'] ?? '').toString() != excludeApplicationId)
          .toList();
    }
    if (data.isEmpty) return;

    final existing = data.first;
    throw Exception(
      'Only one application attempt per school year is allowed. Existing record: ${existing['application_no'] ?? existing['id']}.',
    );
  }

  Future<void> _onSaveDraft() async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _statusMessage = null;
    });
    try {
      final errors = _validate(submitting: false);
      if (errors.isNotEmpty) {
        setState(() {
          _statusMessage = errors.join(' | ');
          _statusIsError = true;
        });
        return;
      }
      final saved = await _saveOrCreateDraft();
      final user = _supabase.auth.currentUser!;
      await _uploadApplicantPhotoIfNeeded(
        userId: user.id,
        applicationId: saved['id'].toString(),
      );
      await _persistAux(user.id, saved['id'].toString());
      await _saveProfile();
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Draft saved (${saved['application_no'] ?? saved['id']}).';
        _statusIsError = false;
        _lastAutoSavedAt = DateTime.now();
        _autoSaveError = null;
      });
      _triggerSavePulse();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Failed to save draft: ${e.toString().replaceFirst('Exception: ', '')}';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _isFilledValue(String value) {
    final normalized = value.trim().toUpperCase();
    return normalized.isNotEmpty &&
        normalized != 'SELECT' &&
        normalized != 'SELECT BARANGAY';
  }

  double _ratio(List<bool> checks) {
    if (checks.isEmpty) return 1;
    final done = checks.where((v) => v).length;
    return done / checks.length;
  }

  double _sectionCompletion(int step) {
    switch (step) {
      case 0:
        return _ratio(<bool>[
          _isFilledValue(_schoolYear),
          _isFilledValue(_applicantCategory),
          _isFilledValue(_grantAppliedFor),
          _selectedPhotoBytes != null ||
              (_storedPhotoPath ?? '').trim().isNotEmpty,
        ]);
      case 1:
        return _ratio(<bool>[
          _isFilledValue(_lastName.text),
          _isFilledValue(_firstName.text),
          _isFilledValue(_sex),
          _isFilledValue(_civilStatus),
          _isFilledValue(_religion),
          _isFilledValue(_birthDate.text),
          _isFilledValue(_placeOfBirth.text),
          _isFilledValue(_sectorClassification),
        ]);
      case 2:
        return 1;
      case 3:
        return _ratio(<bool>[
          _isFilledValue(_selectedBarangay),
          _isFilledValue(_contact.text),
          _isFilledValue(_email.text),
          _isFilledValue(_highestEducationAttainment),
          _isFilledValue(_highestGradeYearLevel),
          _isFilledValue(_gwa.text),
          _isFilledValue(_schoolName.text),
          _isFilledValue(_degreeCourse.text),
          _isFilledValue(_schoolType),
        ]);
      case 4:
        return _ratio(<bool>[
          _isFilledValue(_fatherStatus),
          _isFilledValue(_motherStatus),
          _isFilledValue(_fatherFirstName.text),
          _isFilledValue(_fatherMiddleName.text),
          _isFilledValue(_fatherLastName.text),
          _isFilledValue(_motherFirstName.text),
          _isFilledValue(_motherMiddleName.text),
          _isFilledValue(_motherMaidenName.text),
          _isFilledValue(_fatherAddress.text),
          _isFilledValue(_motherAddress.text),
          _isFilledValue(_fatherOccupation.text),
          _isFilledValue(_motherOccupation.text),
          _isFilledValue(_fatherEducation.text),
          _isFilledValue(_motherEducation.text),
          _isFilledValue(_income.text),
          _isFilledValue(_childrenInFamily.text),
          _isFilledValue(_brotherCount.text),
          _isFilledValue(_sisterCount.text),
        ]);
      case 5:
        if (!_isFilledValue(_spouseName.text) &&
            !_isFilledValue(_spouseChildrenCount.text) &&
            !_isFilledValue(_spouseOccupation.text)) {
          return 1;
        }
        return _ratio(<bool>[
          _isFilledValue(_spouseName.text),
          _isFilledValue(_spouseChildrenCount.text),
          _isFilledValue(_spouseOccupation.text),
        ]);
      case 6:
        return _ratio(<bool>[_agreementChecked, _privacyChecked]);
      default:
        return 0;
    }
  }

  double _overallCompletion() {
    final values = List<double>.generate(
      _stepLabels.length,
      (index) => _sectionCompletion(index),
    );
    if (values.isEmpty) return 0;
    final total = values.reduce((a, b) => a + b);
    return total / values.length;
  }

  String _autoSaveLabel() {
    if (_autoSaving) return 'Saving draft...';
    if (_autoSaveError != null && _autoSaveError!.isNotEmpty) {
      final msg = _autoSaveError!.toLowerCase();
      if (msg.contains('one application attempt per school year')) {
        return 'Autosave blocked: existing application found';
      }
      if (msg.contains('application intake is currently closed')) {
        return 'Autosave blocked: intake is closed';
      }
      return 'Draft autosave failed';
    }
    if (_lastAutoSavedAt == null) return 'Draft not saved yet';
    final diff = DateTime.now().difference(_lastAutoSavedAt!);
    if (diff.inSeconds < 60) return 'Draft saved just now';
    if (diff.inMinutes < 60) return 'Draft saved ${diff.inMinutes}m ago';
    return 'Draft saved ${diff.inHours}h ago';
  }

  Future<void> _autoSaveCurrentStep() async {
    if (!_isEditable() || _saving || _isLoading) return;
    if (_autoSaving) return;

    setState(() {
      _autoSaving = true;
      _autoSaveError = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated applicant session found.');
      }
      final saved = await _saveOrCreateDraft();
      await _persistAux(user.id, saved['id'].toString());
      if (!mounted) return;
      setState(() {
        _lastAutoSavedAt = DateTime.now();
      });
      _triggerSavePulse();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _autoSaveError = e.toString().replaceFirst('Exception: ', '');
        _statusMessage = 'Autosave failed: $_autoSaveError';
        _statusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _autoSaving = false;
        });
      }
    }
  }

  void _goToStep(int step) {
    final clamped = step.clamp(0, _stepLabels.length - 1);
    if (clamped == _currentStep) return;
    if (_saving || _isLoading) return;
    setState(() {
      _currentStep = clamped;
    });
    unawaited(_autoSaveCurrentStep());
  }

  void _triggerSavePulse() {
    if (!mounted) return;
    setState(() {
      _showSavePulse = true;
      _savePulseTick += 1;
    });
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() {
        _showSavePulse = false;
      });
    });
  }

  Future<bool> _confirmFinalSubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Final Submission'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You are about to submit your scholarship application for final review.',
              ),
              SizedBox(height: 12),
              Text('By continuing, you confirm that:'),
              SizedBox(height: 8),
              Text('1. All details provided are complete and accurate.'),
              Text(
                '2. You consent to processing of your personal information under the Data Privacy Notice.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _onSubmit() async {
    if (_saving) return;
    if (!_agreementChecked) {
      setState(() {
        _statusMessage =
            'Please agree that all information is correct before submitting.';
        _statusIsError = true;
      });
      return;
    }
    if (!_privacyChecked) {
      setState(() {
        _statusMessage =
            'Please review and acknowledge the Data Privacy Notice before submitting.';
        _statusIsError = true;
      });
      return;
    }

    final errors = _validate(submitting: true);
    if (errors.isNotEmpty) {
      setState(() {
        _statusMessage = errors.join(' | ');
        _statusIsError = true;
      });
      return;
    }
    final confirmed = await _confirmFinalSubmit();
    if (!confirmed) return;

    setState(() {
      _saving = true;
      _statusMessage = null;
    });
    try {
      final saved = await _saveOrCreateDraft();
      final user = _supabase.auth.currentUser!;
      await _uploadApplicantPhotoIfNeeded(
        userId: user.id,
        applicationId: saved['id'].toString(),
      );
      await _persistAux(user.id, saved['id'].toString());
      await _saveProfile();
      final submittedAt =
          (saved['submitted_at'] ?? DateTime.now().toIso8601String())
              .toString();
      final result = await _supabase
          .from('applications')
          .update(<String, dynamic>{
            'status': 'submitted',
            'submitted_at': submittedAt,
          })
          .eq('id', saved['id'])
          .eq('applicant_id', user.id)
          .select(
            'id, application_no, application_type, scholarship_type, school_year, sector_classification, status, submitted_at, is_locked, created_at, updated_at',
          )
          .single();
      _application = Map<String, dynamic>.from(result);
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Application submitted (${_application!['application_no'] ?? _application!['id']}).';
        _statusIsError = false;
      });
      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Submission failed: ${e.toString().replaceFirst('Exception: ', '')}';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addAward() {
    final nature = _awardNatureDescription.text.trim();
    final school = _awardSchoolName.text.trim();
    final year = _awardYearAwarded.text.trim();
    if (nature.isEmpty && school.isEmpty && year.isEmpty) return;

    final awardTitle = nature.isEmpty ? 'ACADEMIC HONOR' : nature.toUpperCase();
    final awardSchool = school.isEmpty
        ? _schoolName.text.trim().toUpperCase()
        : school.toUpperCase();
    final awardYear = year.isEmpty ? _schoolYear : year;

    _awards.add(<String, String>{
      'natureDescription': awardTitle,
      'schoolName': awardSchool,
      'yearAwarded': awardYear,
    });
    _awardNatureDescription.clear();
    _awardSchoolName.clear();
    _awardYearAwarded.clear();
    setState(() {});
  }

  void _removeAwardAt(int index) {
    if (index < 0 || index >= _awards.length) return;
    _awards.removeAt(index);
    setState(() {});
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    DateTime initialDate = DateTime(now.year - 16, now.month, now.day);
    final raw = _birthDate.text.trim();
    if (raw.isNotEmpty) {
      try {
        initialDate = DateTime.parse(raw);
      } catch (_) {
        // Keep default initial date when stored date format is unexpected.
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Select Date of Birth',
    );
    if (picked == null || !mounted) return;
    final yyyy = picked.year.toString().padLeft(4, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');
    setState(() {
      _birthDate.text = '$yyyy-$mm-$dd';
    });
  }

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFFC8CED8)),
    ),
    child: child,
  );

  Widget _text(
    String label,
    TextEditingController c, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool forceUppercase = false,
  }) => TextField(
    controller: c,
    enabled: _isEditable() && !_saving,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    inputFormatters: <TextInputFormatter>[
      if (forceUppercase) _UpperCaseTextFormatter(),
      ...?inputFormatters,
    ],
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
    ),
  );

  Widget _datePickerField(String label, TextEditingController c) => TextField(
    controller: c,
    readOnly: true,
    enabled: _isEditable() && !_saving,
    onTap: (_isEditable() && !_saving) ? _pickBirthDate : null,
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
      suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
    ),
  );

  Widget _readOnlyText(String label, TextEditingController c) => TextField(
    controller: c,
    readOnly: true,
    enabled: false,
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
    ),
  );

  Widget _select(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged, {
    bool enabled = true,
    Set<String> disabledValues = const <String>{},
  }) {
    final safe = options.contains(value) ? value : options.first;
    final canEdit = _isEditable() && !_saving && enabled;
    return DropdownButtonFormField<String>(
      initialValue: safe,
      onChanged: canEdit
          ? (next) {
              if (next == null) return;
              if (disabledValues.contains(next)) {
                setState(() {
                  _statusMessage =
                      '$next is currently disabled in the web portal.';
                  _statusIsError = true;
                });
                return;
              }
              onChanged(next);
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map(
            (o) => DropdownMenuItem(
              value: o,
              enabled: !disabledValues.contains(o),
              child: Text(o.toUpperCase()),
            ),
          )
          .toList(),
    );
  }

  Widget _grid(List<Widget> children) => LayoutBuilder(
    builder: (context, c) {
      final w = c.maxWidth;
      final cols = w > 1100 ? 4 : (w > 800 ? 3 : (w > 520 ? 2 : 1));
      final cw = (w - ((cols - 1) * _formSpacing)) / cols;
      return Wrap(
        spacing: _formSpacing,
        runSpacing: _formRunSpacing,
        children: children.map((e) => SizedBox(width: cw, child: e)).toList(),
      );
    },
  );

  Widget _familyPanel({
    required String title,
    required List<Widget> children,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFD),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFD9E0EB)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _grid(children),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Scholarship Application')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_errorMessage!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (_application == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Scholarship Application')),
        body: const Center(
          child: Text('Application record not found or access denied.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(title: const Text('Edit Scholarship Application')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text(
              'Complete this final application form and upload your test picture before submission.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 2),
            const Text(
              'Document-style layout based on the official application form.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _statusIsError
                      ? const Color(0xFFFDECEC)
                      : const Color(0xFFEAF7EC),
                  border: Border.all(
                    color: _statusIsError
                        ? const Color(0xFFE8BBBB)
                        : const Color(0xFFB7DEBE),
                  ),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _statusIsError
                        ? const Color(0xFFA0322B)
                        : const Color(0xFF1F6B34),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (_application!['scholarship_type'] ??
                            'Revised Daet Expanded Scholarship Program')
                        .toString(),
                    style: const TextStyle(
                      color: Color(0xFF1E63C5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Application Form',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  StepIndicator(
                    currentStep: _currentStep,
                    labels: _stepLabels,
                    onStepTap: _goToStep,
                  ),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: _sectionCompletion(_currentStep),
                    ),
                    duration: const Duration(milliseconds: 260),
                    builder: (context, value, child) {
                      return ProgressCard(
                        title: 'Section Progress',
                        value: value,
                        caption:
                            '${(_sectionCompletion(_currentStep) * 100).round()}% complete in ${_stepLabels[_currentStep]}',
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  SectionCard(
                    child: Row(
                      children: [
                        TweenAnimationBuilder<double>(
                          key: ValueKey<int>(_savePulseTick),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(
                            begin: 1.0,
                            end: _showSavePulse ? 1.08 : 1.0,
                          ),
                          builder: (context, scale, child) {
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: Icon(
                            _autoSaveError == null
                                ? Icons.cloud_done_outlined
                                : Icons.error_outline,
                            color: _autoSaveError == null
                                ? AppColors.success
                                : AppColors.danger,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _autoSaveLabel(),
                            style: TextStyle(
                              color: _autoSaveError == null
                                  ? AppColors.textSecondary
                                  : AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          'Overall ${(_overallCompletion() * 100).round()}%',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          text: 'Back',
                          onPressed: _currentStep == 0
                              ? null
                              : () => _goToStep(_currentStep - 1),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: PrimaryButton(
                          text: _currentStep == _stepLabels.length - 1
                              ? 'Review'
                              : 'Continue',
                          onPressed: _currentStep == _stepLabels.length - 1
                              ? null
                              : () => _goToStep(_currentStep + 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentStep == 0) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFC8CED8),
                                ),
                                color: const Color(0xFFF8FAFD),
                              ),
                              child: _selectedPhotoBytes != null
                                  ? Image.memory(
                                      _selectedPhotoBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : (_storedPhotoUrl != null
                                        ? Image.network(
                                            _storedPhotoUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                                  Icons.person,
                                                  size: 48,
                                                ),
                                          )
                                        : const Icon(Icons.person, size: 48)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Applicant 1x1 Picture',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  OutlinedButton(
                                    onPressed: (_isEditable() && !_saving)
                                        ? _pickApplicantPhoto
                                        : null,
                                    child: const Text('Choose File'),
                                  ),
                                  if (_selectedPhotoName != null)
                                    Text(
                                      _selectedPhotoName!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF4F5768),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _grid([
                          _select(
                            'School Year',
                            _schoolYear,
                            const ['2024-2025', '2025-2026', '2026-2027'],
                            (v) =>
                                setState(() => _schoolYear = v ?? _schoolYear),
                          ),
                          _select(
                            'Applicant Category',
                            _applicantCategory,
                            const [
                              'NEW APPLICANT',
                              'RENEWAL (TEMPORARILY DISABLED)',
                            ],
                            (v) => setState(
                              () =>
                                  _applicantCategory = v ?? _applicantCategory,
                            ),
                            disabledValues: const {
                              'RENEWAL (TEMPORARILY DISABLED)',
                            },
                          ),
                          _select(
                            'Grant Applied For',
                            _grantAppliedFor,
                            const ['DEGREE COURSE'],
                            (v) => setState(
                              () => _grantAppliedFor = v ?? _grantAppliedFor,
                            ),
                            enabled: false,
                          ),
                          _readOnlyText('Application ID', _applicationNo),
                        ]),
                      ],
                      const Divider(height: 24),
                      if (_currentStep == 1) ...[
                        const Text(
                          'PERSONAL INFORMATION',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _grid([
                          _text(
                            'Last Name',
                            _lastName,
                            forceUppercase: true,
                            textCapitalization: TextCapitalization.characters,
                          ),
                          _text(
                            'First Name',
                            _firstName,
                            forceUppercase: true,
                            textCapitalization: TextCapitalization.characters,
                          ),
                          _text(
                            'Middle Name',
                            _middleName,
                            forceUppercase: true,
                            textCapitalization: TextCapitalization.characters,
                          ),
                          _select('Gender', _sex, const [
                            'SELECT',
                            'Male',
                            'Female',
                          ], (v) => setState(() => _sex = v ?? _sex)),
                          _select(
                            'Status',
                            _civilStatus,
                            const [
                              'SELECT',
                              'Single',
                              'Married',
                              'Widowed',
                              'Separated',
                            ],
                            (v) => setState(
                              () => _civilStatus = v ?? _civilStatus,
                            ),
                          ),
                          _select(
                            'Religion',
                            _religion,
                            const [
                              'SELECT',
                              'ROMAN CATHOLIC',
                              'CHRISTIAN',
                              'ISLAM',
                              'OTHERS',
                            ],
                            (v) => setState(() => _religion = v ?? _religion),
                          ),
                          _datePickerField('Date of Birth', _birthDate),
                          _text(
                            'Place of Birth',
                            _placeOfBirth,
                            forceUppercase: true,
                            textCapitalization: TextCapitalization.characters,
                          ),
                          _select(
                            'Sector Classification',
                            _sectorClassification,
                            const [
                              'Person with Disability (PWD)',
                              'Solo Parent',
                              'Child of Solo Parent',
                              'Child of Farmer',
                              'Child of Fisherfolk',
                              'Orphan',
                              'None of the above',
                            ],
                            (v) => setState(
                              () => _sectorClassification =
                                  v ?? _sectorClassification,
                            ),
                          ),
                        ]),
                      ],
                      const Divider(height: 24),
                      if (_currentStep == 2) ...[
                        const Text(
                          'ACADEMIC AWARDS | HONORS RECEIVED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Optional. You can add up to 5 awards.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6A7283),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _grid([
                          _text(
                            'Nature of Award / Description',
                            _awardNatureDescription,
                            forceUppercase: true,
                            textCapitalization: TextCapitalization.characters,
                          ),
                          _text(
                            'What School',
                            _awardSchoolName,
                            forceUppercase: true,
                            textCapitalization: TextCapitalization.characters,
                          ),
                          _text(
                            'Date or Year Awarded',
                            _awardYearAwarded,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9-]'),
                              ),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            onPressed:
                                (_isEditable() &&
                                    !_saving &&
                                    _awards.length < 5)
                                ? _addAward
                                : null,
                            child: Text(
                              _awards.length >= 5
                                  ? 'Max Awards Reached'
                                  : 'Add Award',
                            ),
                          ),
                        ),
                        if (_awards.isNotEmpty)
                          ..._awards.asMap().entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6F8FC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFD9E0EB),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.value['natureDescription']} | ${entry.value['schoolName']} | ${entry.value['yearAwarded']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF3D4557),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          side: const BorderSide(
                                            color: Color(0xFFB77AF2),
                                          ),
                                          foregroundColor: Color(0xFF8A45D0),
                                        ),
                                        onPressed: (_isEditable() && !_saving)
                                            ? () => _removeAwardAt(entry.key)
                                            : null,
                                        child: const Text(
                                          'Remove',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                      const Divider(height: 24),
                      if (_currentStep == 3) ...[
                        const Text(
                          'PERMANENT ADDRESS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _grid([
                          _text(
                            'House No. / Purok / Sitio',
                            _addressLine,
                            forceUppercase: true,
                            textCapitalization: TextCapitalization.characters,
                          ),
                          _select(
                            'Barangay',
                            _selectedBarangay,
                            _barangayOptions,
                            (v) {
                              final next = v ?? 'SELECT BARANGAY';
                              setState(() {
                                _selectedBarangay = next;
                                _barangay.text = next == 'SELECT BARANGAY'
                                    ? ''
                                    : next;
                              });
                            },
                          ),
                          _select(
                            'Municipality',
                            _municipality,
                            const ['DAET'],
                            (v) => setState(
                              () => _municipality = v ?? _municipality,
                            ),
                            enabled: false,
                          ),
                          _text('Contact Number', _contact),
                          _text('Email Address', _email),
                          _select(
                            'Highest Educational Attainment',
                            _highestEducationAttainment,
                            const [
                              'SELECT',
                              'SENIOR HIGH SCHOOL GRADUATE',
                              'COLLEGE LEVEL',
                              'ALS GRADUATE',
                            ],
                            (v) => setState(
                              () => _highestEducationAttainment =
                                  v ?? _highestEducationAttainment,
                            ),
                          ),
                          _select(
                            'Highest Grade/Year Level',
                            _highestGradeYearLevel,
                            const [
                              'SELECT',
                              'GRADE 12',
                              '1ST YEAR',
                              '2ND YEAR',
                              '3RD YEAR',
                              '4TH YEAR',
                              '5TH YEAR',
                            ],
                            (v) => setState(
                              () => _highestGradeYearLevel =
                                  v ?? _highestGradeYearLevel,
                            ),
                          ),
                          _text(
                            'General Weighted Average (0-100)',
                            _gwa,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                          ),
                          _text(
                            'School Name',
                            _schoolName,
                            forceUppercase: true,
                            textCapitalization: TextCapitalization.characters,
                          ),
                          _text(
                            'Degree Course',
                            _degreeCourse,
                            forceUppercase: true,
                            textCapitalization: TextCapitalization.characters,
                          ),
                          _select(
                            'School Type',
                            _schoolType,
                            const ['PUBLIC', 'PRIVATE'],
                            (v) =>
                                setState(() => _schoolType = v ?? _schoolType),
                          ),
                        ]),
                      ],
                      const Divider(height: 24),
                      if (_currentStep == 4) ...[
                        const Text(
                          'FAMILY BACKGROUND',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final showTwoColumns = constraints.maxWidth >= 900;
                            final fatherPanel = _familyPanel(
                              title: 'Father',
                              children: [
                                _select(
                                  'Father Status',
                                  _fatherStatus,
                                  const ['Alive', 'Deceased'],
                                  (v) => setState(
                                    () => _fatherStatus = v ?? _fatherStatus,
                                  ),
                                ),
                                _text(
                                  'First Name',
                                  _fatherFirstName,
                                  forceUppercase: true,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                                _text(
                                  'Middle Name',
                                  _fatherMiddleName,
                                  forceUppercase: true,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                                _text(
                                  'Surname',
                                  _fatherLastName,
                                  forceUppercase: true,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                                _text(
                                  'Address',
                                  _fatherAddress,
                                  forceUppercase: true,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                                _text(
                                  'Occupation',
                                  _fatherOccupation,
                                  forceUppercase: true,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                                _text(
                                  'Educational Attainment',
                                  _fatherEducation,
                                  forceUppercase: true,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                              ],
                            );
                            final motherPanel = _familyPanel(
                              title: 'Mother',
                              children: [
                                _select(
                                  'Mother Status',
                                  _motherStatus,
                                  const ['Alive', 'Deceased'],
                                  (v) => setState(
                                    () => _motherStatus = v ?? _motherStatus,
                                  ),
                                ),
                                _text(
                                  'First Name',
                                  _motherFirstName,
                                  forceUppercase: true,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                                _text(
                                  'Middle Name',
                                  _motherMiddleName,
                                  forceUppercase: true,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                                _text(
                                  'Maiden Name',
                                  _motherMaidenName,
                                  forceUppercase: true,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                                _text(
                                  'Address',
                                  _motherAddress,
                                  forceUppercase: true,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                                _text(
                                  'Occupation',
                                  _motherOccupation,
                                  forceUppercase: true,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                                _text(
                                  'Educational Attainment',
                                  _motherEducation,
                                  forceUppercase: true,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                              ],
                            );
                            if (showTwoColumns) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: fatherPanel),
                                  const SizedBox(width: 14),
                                  Expanded(child: motherPanel),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                fatherPanel,
                                const SizedBox(height: 12),
                                motherPanel,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _grid([
                          _text(
                            'No. of Children in Family',
                            _childrenInFamily,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                          _text(
                            'No. of Brothers',
                            _brotherCount,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                          _text(
                            'No. of Sisters',
                            _sisterCount,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                          _text(
                            'Total Parents Gross Income (PHP)',
                            _income,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                          ),
                        ]),
                      ],
                      const Divider(height: 24),
                      if (_currentStep == 5) ...[
                        const Text(
                          'FOR MARRIED OR LIVING TOGETHER APPLICANT ONLY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _grid([
                          _text(
                            'Name of Husband / Wife',
                            _spouseName,
                            forceUppercase: true,
                            textCapitalization: TextCapitalization.characters,
                          ),
                          _text(
                            'No. of Children',
                            _spouseChildrenCount,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                          _text(
                            'Occupation',
                            _spouseOccupation,
                            forceUppercase: true,
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ]),
                      ],
                      if (_currentStep == 6) ...[
                        const Divider(height: 24),
                        const Text(
                          'REVIEW & CONSENT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          dense: false,
                          visualDensity: VisualDensity.standard,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                          value: _agreementChecked,
                          onChanged: (v) =>
                              setState(() => _agreementChecked = v ?? false),
                          title: const Text(
                            'I agree that all information in this form is true and correct.',
                            style: TextStyle(fontSize: 13, height: 1.3),
                          ),
                        ),
                        CheckboxListTile(
                          dense: false,
                          visualDensity: VisualDensity.standard,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                          value: _privacyChecked,
                          onChanged: (v) =>
                              setState(() => _privacyChecked = v ?? false),
                          title: const Text(
                            'I have read and understood the Data Privacy Notice.',
                            style: TextStyle(fontSize: 13, height: 1.3),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: (_saving || !_isEditable())
                                    ? null
                                    : _onSaveDraft,
                                child: Text(
                                  _saving ? 'Saving...' : 'Save Draft',
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2A303C),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: (_saving || !_isEditable())
                                    ? null
                                    : _onSubmit,
                                child: Text(
                                  _saving
                                      ? 'Submitting...'
                                      : 'Submit Application',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
