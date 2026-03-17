import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  late Future<_ProfileData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<_ProfileData> _loadProfile() async {
    final user = await _api.getProfile();
    final role = user['role'] as String? ?? 'CITIZEN';
    List<ActivityLog> logs = [];
    if (_isStaff(role)) {
      try {
        logs = await _api.getActivityLog();
      } catch (_) {}
    }
    return _ProfileData(user: user, activityLogs: logs);
  }

  bool _isStaff(String role) =>
      ['ADMIN', 'PWD', 'SANITATION', 'ELECTRICITY', 'CREW'].contains(role);

  void _refresh() {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: widget.onLogout,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: FutureBuilder<_ProfileData>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 48),
                  const SizedBox(height: 16),
                  Text('Error loading profile', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(),
                      style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('RETRY'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final user = data.user;
          final role = user['role'] as String? ?? 'CITIZEN';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  // ── Avatar & basic info ──────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentTeal.withOpacity(0.3), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentTeal.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 56,
                      backgroundColor: AppTheme.cardBackground,
                      child: Icon(Icons.person_outline_rounded, size: 60, color: AppTheme.accentTeal),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    user['username'] ?? 'User',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textHighContrast,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user['email'] ?? '',
                    style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
                    ),
                    child: Text(
                      role,
                      style: const TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Role-specific content ────────────────────────────
                  if (_isStaff(role))
                    _StaffActivitySection(
                      user: user,
                      logs: data.activityLogs,
                    )
                  else
                    _CitizenStatsSection(user: user),

                  const SizedBox(height: 32),

                  // ── Sign Out button ──────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.dangerRed.withOpacity(0.1),
                        foregroundColor: AppTheme.dangerRed,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: AppTheme.dangerRed.withOpacity(0.3)),
                        ),
                      ),
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout_rounded, size: 24),
                      label: const Text('SIGN OUT',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(fontSize: 16, color: AppTheme.textMediumContrast)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: AppTheme.textHighContrast,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ApiService().logout();
              widget.onLogout();
            },
            child: const Text('SIGN OUT'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper data container
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileData {
  const _ProfileData({required this.user, required this.activityLogs});
  final Map<String, dynamic> user;
  final List<ActivityLog> activityLogs;
}

// ─────────────────────────────────────────────────────────────────────────────
// Citizen: trust score card + stats (unchanged UX)
// ─────────────────────────────────────────────────────────────────────────────
class _CitizenStatsSection extends StatelessWidget {
  const _CitizenStatsSection({required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final trustScore = (user['trust_score'] as num?)?.toInt() ?? 50;
    final reportsCount = (user['reports_count'] as num?)?.toInt() ?? 0;
    final resolvedCount = (user['resolved_count'] as num?)?.toInt() ?? 0;
    final scoreColor = trustScore > 70
        ? AppTheme.successGreen
        : (trustScore > 40 ? AppTheme.warningOrange : AppTheme.dangerRed);

    return Column(
      children: [
        // Trust Score Card
        Card(
          elevation: 4,
          shadowColor: scoreColor.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(color: scoreColor.withOpacity(0.3)),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.cardBackground, scoreColor.withOpacity(0.05)],
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
            child: Column(
              children: [
                const Text('CREDIBILITY SCORE',
                    style: TextStyle(
                        color: AppTheme.textMediumContrast,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                const SizedBox(height: 32),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 160,
                      width: 160,
                      child: CircularProgressIndicator(
                        value: trustScore / 100,
                        strokeWidth: 16,
                        backgroundColor: AppTheme.darkBackground,
                        color: scoreColor,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$trustScore',
                            style: TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w800,
                                color: scoreColor,
                                height: 1.0)),
                        const Text('%',
                            style: TextStyle(
                                color: AppTheme.textMediumContrast,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    trustScore > 70
                        ? 'ELITE CITIZEN'
                        : (trustScore > 40 ? 'VERIFIED' : 'RESTRICTED'),
                    style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        // Stats Row
        Row(
          children: [
            Expanded(child: _StatCard('REPORTS', '$reportsCount', Icons.analytics_outlined, AppTheme.primaryBlue)),
            const SizedBox(width: 16),
            Expanded(child: _StatCard('RESOLVED', '$resolvedCount', Icons.check_circle_outline, AppTheme.accentTeal)),
          ],
        ),
        const SizedBox(height: 32),
        // Credibility info
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppTheme.textMediumContrast.withOpacity(0.1)),
          ),
          color: AppTheme.cardBackground,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppTheme.accentTeal, size: 24),
                    SizedBox(width: 12),
                    Text('CREDIBILITY SYSTEM',
                        style: TextStyle(
                            color: AppTheme.textHighContrast,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your score represents your contribution to the city. Higher scores are achieved by reporting valid civic issues and lead to priority verification.',
                  style: TextStyle(color: AppTheme.textMediumContrast, fontSize: 15, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.icon, this.color);
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 16),
            Text(value,
                style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast)),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textMediumContrast,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin / Department / Crew: Activity Summary (no metrics)
// ─────────────────────────────────────────────────────────────────────────────
class _StaffActivitySection extends StatelessWidget {
  const _StaffActivitySection({required this.user, required this.logs});
  final Map<String, dynamic> user;
  final List<ActivityLog> logs;

  String _formatLastLogin(dynamic raw) {
    if (raw == null) return 'Not available';
    try {
      final dt = DateTime.parse(raw as String).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      final timeStr =
          '${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
      if (diff.inDays == 0) return 'Today at $timeStr';
      if (diff.inDays == 1) return 'Yesterday at $timeStr';
      return '${dt.day}/${dt.month}/${dt.year} at $timeStr';
    } catch (_) {
      return raw.toString();
    }
  }

  String _formatLogTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final amPm = local.hour >= 12 ? 'PM' : 'AM';
    final dateStr = '${local.day}/${local.month}/${local.year}';
    return '$dateStr $h:$m $amPm';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Section header ─────────────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.history_rounded, color: AppTheme.accentTeal, size: 22),
            ),
            const SizedBox(width: 14),
            const Text(
              'ACTIVITY SUMMARY',
              style: TextStyle(
                color: AppTheme.textHighContrast,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Last Login ─────────────────────────────────────────
        Card(
          elevation: 0,
          color: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.textMediumContrast.withOpacity(0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.login_rounded, color: AppTheme.primaryBlue, size: 20),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LAST LOGIN',
                        style: TextStyle(
                            color: AppTheme.textMediumContrast,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    Text(
                      _formatLastLogin(user['last_login']),
                      style: const TextStyle(
                          color: AppTheme.textHighContrast, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Recent Actions header ──────────────────────────────
        const Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: AppTheme.textMediumContrast, size: 18),
            SizedBox(width: 10),
            Text('RECENT ACTIONS',
                style: TextStyle(
                    color: AppTheme.textMediumContrast,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8)),
          ],
        ),
        const SizedBox(height: 12),

        // ── Timeline list ──────────────────────────────────────
        if (logs.isEmpty)
          Card(
            elevation: 0,
            color: AppTheme.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.textMediumContrast.withOpacity(0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 48, color: AppTheme.textMediumContrast.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  const Text('No recent activity recorded.',
                      style: TextStyle(color: AppTheme.textMediumContrast, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('Actions you perform will appear here.',
                      style: TextStyle(color: AppTheme.textMediumContrast, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          Card(
            elevation: 0,
            color: AppTheme.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.textMediumContrast.withOpacity(0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (_, __) =>
                    Divider(color: AppTheme.textMediumContrast.withOpacity(0.08), height: 1, indent: 20, endIndent: 20),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline dot
                        Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: index == 0
                                    ? AppTheme.accentTeal
                                    : AppTheme.textMediumContrast.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.action,
                                style: TextStyle(
                                  color: index == 0
                                      ? AppTheme.textHighContrast
                                      : AppTheme.textHighContrast.withOpacity(0.85),
                                  fontSize: 14,
                                  fontWeight: index == 0 ? FontWeight.w600 : FontWeight.normal,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '[${_formatLogTime(log.timestamp)}]',
                                style: const TextStyle(
                                    color: AppTheme.textMediumContrast,
                                    fontSize: 11,
                                    letterSpacing: 0.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
