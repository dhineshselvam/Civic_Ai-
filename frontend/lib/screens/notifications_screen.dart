import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => _api.markNotificationsRead().then((_) => _loadNotifications()),
            child: const Text('Mark all as read', style: TextStyle(color: Colors.tealAccent, fontSize: 12)),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigo.shade900, Colors.teal.shade800, Colors.black],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text('Your inbox is empty', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                      ],
                    ),
                  )
                : SafeArea(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final n = _notifications[index];
                        final isRead = n['is_read'] == true;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isRead ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isRead ? Colors.white.withOpacity(0.05) : Colors.tealAccent.withOpacity(0.2)),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Stack(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isRead ? Colors.white10 : Colors.tealAccent.withOpacity(0.2),
                                        child: Icon(
                                          isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded, 
                                          color: isRead ? Colors.white38 : Colors.tealAccent, 
                                          size: 20
                                        ),
                                      ),
                                      if (!isRead)
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Text(
                                    n['title'],
                                    style: TextStyle(
                                      color: isRead ? Colors.white70 : Colors.white,
                                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      n['message'],
                                      style: TextStyle(color: Colors.white.withOpacity(isRead ? 0.3 : 0.5), fontSize: 12),
                                    ),
                                  ),
                                  trailing: Text(
                                    _formatDate(n['created_at']),
                                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
}
