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
        // Mark as read after a short delay
        Future.delayed(const Duration(seconds: 2), () => _api.markNotificationsRead());
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => _api.markNotificationsRead().then((_) => _loadNotifications()),
            child: const Text('Mark all as read', style: TextStyle(color: AppTheme.accentTeal, fontSize: 14)),
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
                      Icon(Icons.notifications_off_outlined, size: 80, color: AppTheme.textMediumContrast.withOpacity(0.5)),
                      const SizedBox(height: 24),
                      Text('Your inbox is empty', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.textMediumContrast)),
                    ],
                  ),
                )
              : SafeArea(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isRead = n['is_read'] == true;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Card(
                          elevation: isRead ? 0 : 4,
                          color: isRead ? AppTheme.darkBackground : AppTheme.cardBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isRead ? AppTheme.textMediumContrast.withOpacity(0.1) : AppTheme.accentTeal.withOpacity(0.3),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: isRead ? AppTheme.cardBackground : AppTheme.accentTeal.withOpacity(0.15),
                                      child: Icon(
                                        isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded, 
                                        color: isRead ? AppTheme.textMediumContrast : AppTheme.accentTeal, 
                                        size: 24
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
                                            border: Border.all(color: AppTheme.cardBackground, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              n['title'],
                                              style: TextStyle(
                                                color: isRead ? AppTheme.textMediumContrast : AppTheme.textHighContrast,
                                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatDate(n['created_at']),
                                            style: TextStyle(fontSize: 12, color: AppTheme.textMediumContrast.withOpacity(isRead ? 0.5 : 1.0)),
                                          ),
                                        ],
                                      ),
                                      if (_extractReportId(n['message'] ?? '') != null) ...[
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
                                        n['message'],
                                        style: TextStyle(
                                          color: isRead ? AppTheme.textMediumContrast : AppTheme.textHighContrast.withOpacity(0.9), 
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
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDate(String iso) {
    try {
      final date = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
      }
      return "${date.day}/${date.month}";
    } catch (e) {
      return "";
    }
  }

  /// Extracts a complaint ID number from a notification message.
  /// Looks for patterns like "Report #42", "report #42", "#42", "task #42".
  String? _extractReportId(String message) {
    final match = RegExp(r'[Rr]eport\s+#?(\d+)|[Tt]ask\s+#?(\d+)|#(\d+)').firstMatch(message);
    if (match == null) return null;
    return match.group(1) ?? match.group(2) ?? match.group(3);
  }
}
