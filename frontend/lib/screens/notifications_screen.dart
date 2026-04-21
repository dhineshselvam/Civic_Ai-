import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() => _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await _api.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    await _api.markNotificationsRead();
    _loadNotifications();
  }

  Future<void> _markOneRead(dynamic n) async {
    if (n['is_read'] == true) return;
    final id = n['id'] as int?;
    if (id == null) return;
    await _api.markNotificationRead(id);
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read',
                style: TextStyle(color: AppTheme.accentTeal, fontSize: 14)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          size: 80,
                          color: AppTheme.textMediumContrast.withOpacity(0.5)),
                      const SizedBox(height: 24),
                      Text('Your inbox is empty',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: AppTheme.textMediumContrast)),
                    ],
                  ),
                )
              : SafeArea(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isRead = n['is_read'] == true;
                      final type = n['type'] as String? ?? 'general';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GestureDetector(
                          onTap: () => _markOneRead(n),
                          child: Card(
                            elevation: isRead ? 0 : 4,
                            color: isRead
                                ? AppTheme.darkBackground
                                : AppTheme.cardBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isRead
                                    ? AppTheme.textMediumContrast.withOpacity(0.1)
                                    : _typeAccent(type).withOpacity(0.4),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon column
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: isRead
                                            ? AppTheme.cardBackground
                                            : _typeAccent(type).withOpacity(0.15),
                                        child: Icon(
                                          _typeIcon(type),
                                          color: isRead
                                              ? AppTheme.textMediumContrast
                                              : _typeAccent(type),
                                          size: 24,
                                        ),
                                      ),
                                      if (!isRead)
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: AppTheme.warningOrange,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: AppTheme.cardBackground,
                                                  width: 2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  // Content column
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Title row + timestamp
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                n['title'] ?? '',
                                                style: TextStyle(
                                                  color: isRead
                                                      ? AppTheme
                                                          .textMediumContrast
                                                      : AppTheme
                                                          .textHighContrast,
                                                  fontWeight: isRead
                                                      ? FontWeight.normal
                                                      : FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatDate(
                                                  n['created_at'] ?? ''),
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme
                                                      .textMediumContrast
                                                      .withOpacity(
                                                          isRead ? 0.5 : 1.0)),
                                            ),
                                          ],
                                        ),
                                        // Type badge (only for SLA types)
                                        if (type != 'general') ...[
                                          const SizedBox(height: 6),
                                          _TypeBadge(type: type),
                                        ],
                                        // Report ID extraction
                                        if (_extractReportId(
                                                n['message'] ?? '') !=
                                            null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Report ID: ${_extractReportId(n['message']!)}',
                                            style: const TextStyle(
                                              color: AppTheme.accentTeal,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(
                                          n['message'] ?? '',
                                          style: TextStyle(
                                            color: isRead
                                                ? AppTheme.textMediumContrast
                                                : AppTheme.textHighContrast
                                                    .withOpacity(0.9),
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  // ─── helpers ────────────────────────────────────────────────────────────

  Color _typeAccent(String type) {
    switch (type) {
      case 'response_warning':
        return Colors.orange;
      case 'resolution_warning':
        return Colors.amber;
      case 'breach':
        return Colors.red;
      default:
        return AppTheme.accentTeal;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'response_warning':
        return Icons.bolt_rounded;
      case 'resolution_warning':
        return Icons.alarm_rounded;
      case 'breach':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _formatDate(String iso) {
    try {
      final date = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (date.day == now.day &&
          date.month == now.month &&
          date.year == now.year) {
        return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
      return '${date.day}/${date.month}';
    } catch (e) {
      return '';
    }
  }

  String? _extractReportId(String message) {
    final match =
        RegExp(r'[Rr]eport\s+#?(\d+)|[Tt]ask\s+#?(\d+)|#(\d+)')
            .firstMatch(message);
    if (match == null) return null;
    return match.group(1) ?? match.group(2) ?? match.group(3);
  }
}

// ─── Type badge widget ────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final info = _badgeInfo(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: info.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: info.color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(info.emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            info.label,
            style: TextStyle(
              color: info.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeInfo _badgeInfo(String type) {
    switch (type) {
      case 'response_warning':
        return _BadgeInfo('⚡', 'Response Due', Colors.orange);
      case 'resolution_warning':
        return _BadgeInfo('⏰', 'SLA Warning', Colors.amber);
      case 'breach':
        return _BadgeInfo('🚨', 'SLA Breach', Colors.red);
      default:
        return _BadgeInfo('', '', AppTheme.accentTeal);
    }
  }
}

class _BadgeInfo {
  const _BadgeInfo(this.emoji, this.label, this.color);
  final String emoji;
  final String label;
  final Color color;
}
