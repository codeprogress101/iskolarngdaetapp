import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;
  String? _statusMessage;
  bool _supportsDismissedAt = true;
  bool _supportsReadAt = true;
  final List<_NotificationRow> _rows = <_NotificationRow>[];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  bool _isMissingColumnError(PostgrestException exception, String columnName) {
    final message = exception.message.toLowerCase();
    return message.contains('column') &&
        message.contains(columnName.toLowerCase());
  }

  String _schemaMismatchMessage(PostgrestException exception) {
    final message = exception.message;
    final columnMatch = RegExp(
      r'column\s+([a-zA-Z0-9_]+\.[a-zA-Z0-9_]+)\s+does not exist',
      caseSensitive: false,
    ).firstMatch(message);
    final relationMatch = RegExp(
      r'relation\s+"?([a-zA-Z0-9_]+)"?\s+does not exist',
      caseSensitive: false,
    ).firstMatch(message);
    if (columnMatch != null || relationMatch != null) {
      return 'Schema mismatch: $message';
    }
    return 'Failed to load notifications. Please try again.';
  }

  Future<List<Map<String, dynamic>>> _fetchRows(String userId) async {
    Future<List<Map<String, dynamic>>> runQuery({
      required bool includeDismissedFilter,
      required bool includeReadAt,
    }) async {
      final fields = includeReadAt
          ? 'id, notification_type, title, message, related_application_id, related_url, is_read, read_at, created_at'
          : 'id, notification_type, title, message, related_application_id, related_url, is_read, created_at';
      dynamic query = _supabase
          .from('notifications')
          .select(fields)
          .eq('recipient_user_id', userId);
      if (includeDismissedFilter) {
        query = query.isFilter('dismissed_at', null);
      }
      final result = await query
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(const Duration(seconds: 12));
      return List<Map<String, dynamic>>.from(result as List);
    }

    try {
      return await runQuery(includeDismissedFilter: true, includeReadAt: true);
    } on PostgrestException catch (e) {
      if (_isMissingColumnError(e, 'read_at')) {
        _supportsReadAt = false;
        return await runQuery(
          includeDismissedFilter: true,
          includeReadAt: false,
        );
      }
      if (_isMissingColumnError(e, 'dismissed_at')) {
        _supportsDismissedAt = false;
        try {
          return await runQuery(
            includeDismissedFilter: false,
            includeReadAt: true,
          );
        } on PostgrestException catch (nested) {
          if (_isMissingColumnError(nested, 'read_at')) {
            _supportsReadAt = false;
            return await runQuery(
              includeDismissedFilter: false,
              includeReadAt: false,
            );
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<void> _loadNotifications() async {
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

      final rows = await _fetchRows(user.id);

      if (!mounted) return;
      final parsedRows = <_NotificationRow>[];
      for (final row in rows) {
        try {
          parsedRows.add(_NotificationRow.fromMap(row));
        } catch (_) {
          // Keep rendering the page even when one row has malformed payload.
        }
      }

      setState(() {
        _rows
          ..clear()
          ..addAll(parsedRows);
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Request timed out while loading notifications.';
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _schemaMismatchMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(_NotificationRow row) async {
    if (row.isRead) return;
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No authenticated applicant session found.'),
        ),
      );
      return;
    }

    try {
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', row.id)
          .eq('recipient_user_id', user.id)
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;
      setState(() {
        row.isRead = true;
        row.readAt = DateTime.now().toUtc();
        _statusMessage = 'Notification marked as read.';
      });
    } on PostgrestException catch (e) {
      if (_isMissingColumnError(e, 'read_at')) {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('id', row.id)
            .eq('recipient_user_id', user.id)
            .timeout(const Duration(seconds: 12));
        if (!mounted) return;
        setState(() {
          row.isRead = true;
          _statusMessage = 'Notification marked as read.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to update notification. Please try again.';
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Request timed out while updating notification.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = e.toString().replaceFirst('Exception: ', '');
      });
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

  String _typeLabel(String? type) {
    final normalized = (type ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return 'Info';
    return normalized
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8DCE4)),
      ),
      child: child,
    );
  }

  Widget _buildItem(_NotificationRow row) {
    final badgeColor = row.isRead
        ? const Color(0xFFE7ECF3)
        : const Color(0xFFDFF0FF);
    final badgeTextColor = row.isRead
        ? const Color(0xFF3A4355)
        : const Color(0xFF1E63C5);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.title.isEmpty ? 'Notification' : row.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E3445),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  row.isRead ? 'Read' : 'Unread',
                  style: TextStyle(
                    color: badgeTextColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EDF3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _typeLabel(row.notificationType),
                  style: const TextStyle(
                    color: Color(0xFF2E3445),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                _formatDateTime(row.createdAt),
                style: const TextStyle(color: Color(0xFF5C6476), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            row.message.isEmpty ? '-' : row.message,
            style: const TextStyle(color: Color(0xFF2E3445), height: 1.35),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: row.isRead ? null : () => _markAsRead(row),
                child: const Text('Mark as read'),
              ),
              if (row.relatedApplicationId?.isNotEmpty == true)
                TextButton(
                  onPressed: () {
                    final applicationId = (row.relatedApplicationId ?? '')
                        .trim();
                    if (applicationId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Application record is unavailable.'),
                        ),
                      );
                      return;
                    }
                    context.push('/applications/$applicationId');
                  },
                  child: const Text('Open application'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _safeNotificationCard(_NotificationRow row) {
    try {
      return _buildItem(row);
    } catch (e) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unable to render one notification item.',
              style: TextStyle(
                color: Color(0xFF2E3445),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This item has an invalid payload.',
              style: TextStyle(color: Color(0xFF5C6476), fontSize: 12),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 40),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadNotifications,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadNotifications,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    if (_statusMessage != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF3F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC8D3E3)),
                        ),
                        child: Text(
                          _statusMessage!,
                          style: const TextStyle(color: Color(0xFF2E3445)),
                        ),
                      ),
                    ],
                    if (!_supportsDismissedAt)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEBCB8B)),
                        ),
                        child: const Text(
                          'Fallback active: notifications.dismissed_at column is unavailable.',
                          style: TextStyle(color: Color(0xFF7A5B1D)),
                        ),
                      ),
                    if (!_supportsReadAt)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEBCB8B)),
                        ),
                        child: const Text(
                          'Fallback active: notifications.read_at column is unavailable.',
                          style: TextStyle(color: Color(0xFF7A5B1D)),
                        ),
                      ),
                    Text(
                      '${_rows.where((row) => !row.isRead).length} unread',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E3445),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_rows.isEmpty)
                      _card(
                        child: const Text(
                          'You are all caught up. New updates will appear here.',
                          style: TextStyle(
                            color: Color(0xFF5C6476),
                            height: 1.3,
                          ),
                        ),
                      )
                    else
                      ..._rows.map(_safeNotificationCard),
                  ],
                ),
              ),
      ),
    );
  }
}

class _NotificationRow {
  _NotificationRow({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.message,
    required this.relatedApplicationId,
    required this.relatedUrl,
    required this.isRead,
    required this.createdAt,
    required this.readAt,
  });

  factory _NotificationRow.fromMap(Map<String, dynamic> map) {
    return _NotificationRow(
      id: (map['id'] ?? '').toString(),
      notificationType: map['notification_type']?.toString(),
      title: (map['title'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      relatedApplicationId: map['related_application_id']?.toString(),
      relatedUrl: map['related_url']?.toString(),
      isRead: map['is_read'] == true,
      createdAt: map['created_at'],
      readAt: DateTime.tryParse((map['read_at'] ?? '').toString()),
    );
  }

  final String id;
  final String? notificationType;
  final String title;
  final String message;
  final String? relatedApplicationId;
  final String? relatedUrl;
  bool isRead;
  final dynamic createdAt;
  DateTime? readAt;
}
