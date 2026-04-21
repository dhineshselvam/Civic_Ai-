import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key, this.title = 'ALL REPORTS'});
  final String title;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  bool _loading = true;
  List<Complaint> _reports = [];
  late TabController _tabController;

  static const _tabs = [
    (label: 'UNVERIFIED', icon: Icons.help_outline_rounded),
    (label: 'VERIFIED',   icon: Icons.verified_rounded),
    (label: 'FLAGGED',    icon: Icons.flag_rounded),
    (label: 'RESOLVED',   icon: Icons.check_circle_outline_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final reports = await _api.getComplaints();
      if (mounted) setState(() => _reports = reports);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Tab filters ────────────────────────────────────────────────────────────

  List<Complaint> get _unverified => _reports
      .where((r) => r.genuinityStatus == 'Unverified' && r.status != 'Resolved')
      .toList();

  List<Complaint> get _verified => _reports
      .where((r) => r.genuinityStatus == 'Verified' && r.status != 'Resolved')
      .toList();

  List<Complaint> get _flagged => _reports
      .where((r) =>
          r.genuinityStatus == 'Flagged' ||
          r.predicted_category.toLowerCase() == 'spam')
      .toList();

  List<Complaint> get _resolved =>
      _reports.where((r) => r.status == 'Resolved').toList();

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded)),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          indicatorColor: AppTheme.accentTeal,
          labelColor: AppTheme.accentTeal,
          unselectedLabelColor: AppTheme.textMediumContrast,
          tabs: [
            _Tab(label: _tabs[0].label, icon: _tabs[0].icon, count: _unverified.length, badgeColor: AppTheme.warningOrange),
            _Tab(label: _tabs[1].label, icon: _tabs[1].icon, count: _verified.length,   badgeColor: Colors.cyan),
            _Tab(label: _tabs[2].label, icon: _tabs[2].icon, count: _flagged.length,    badgeColor: AppTheme.dangerRed),
            _Tab(label: _tabs[3].label, icon: _tabs[3].icon, count: _resolved.length,   badgeColor: AppTheme.successGreen),
          ],
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _ReportsList(
                    reports: _unverified,
                    emptyMessage: 'No unverified complaints',
                    emptyIcon: Icons.verified_user_outlined,
                    cardBuilder: (r) => _AdminReportCard(
                      report: r,
                      onRefresh: _loadData,
                      cardType: _CardType.unverified,
                    ),
                  ),
                  _ReportsList(
                    reports: _verified,
                    emptyMessage: 'No verified complaints',
                    emptyIcon: Icons.inbox_outlined,
                    cardBuilder: (r) => _AdminReportCard(
                      report: r,
                      onRefresh: _loadData,
                      cardType: _CardType.verified,
                    ),
                  ),
                  _ReportsList(
                    reports: _flagged,
                    emptyMessage: 'No flagged or spam complaints',
                    emptyIcon: Icons.shield_outlined,
                    cardBuilder: (r) => _AdminReportCard(
                      report: r,
                      onRefresh: _loadData,
                      cardType: _CardType.flagged,
                    ),
                  ),
                  _ReportsList(
                    reports: _resolved,
                    emptyMessage: 'No resolved complaints yet',
                    emptyIcon: Icons.celebration_outlined,
                    cardBuilder: (r) => _AdminReportCard(
                      report: r,
                      onRefresh: _loadData,
                      cardType: _CardType.resolved,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Tab widget with count badge ──────────────────────────────────────────────

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.icon, required this.count, required this.badgeColor});
  final String label;
  final IconData icon;
  final int count;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Empty / list wrapper ─────────────────────────────────────────────────────

class _ReportsList extends StatelessWidget {
  const _ReportsList({
    required this.reports,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.cardBuilder,
  });
  final List<Complaint> reports;
  final String emptyMessage;
  final IconData emptyIcon;
  final Widget Function(Complaint) cardBuilder;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 72, color: AppTheme.textMediumContrast.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(emptyMessage, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textMediumContrast)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: reports.length,
      itemBuilder: (context, idx) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: cardBuilder(reports[idx]),
      ),
    );
  }
}

// ── Card type enum ───────────────────────────────────────────────────────────

enum _CardType { unverified, verified, flagged, resolved }

// ── Report card ──────────────────────────────────────────────────────────────

class _AdminReportCard extends StatelessWidget {
  _AdminReportCard({required this.report, required this.onRefresh, required this.cardType});
  final Complaint report;
  final VoidCallback onRefresh;
  final _CardType cardType;
  final _api = ApiService();

  Color _genuinityColor() {
    switch (report.genuinityStatus) {
      case 'Verified':   return Colors.cyan;
      case 'Flagged':    return AppTheme.dangerRed;
      case 'Unverified': return AppTheme.warningOrange;
      default:           return AppTheme.textMediumContrast;
    }
  }

  IconData _genuinityIcon() {
    switch (report.genuinityStatus) {
      case 'Verified':   return Icons.verified_user_rounded;
      case 'Flagged':    return Icons.flag_rounded;
      case 'Unverified': return Icons.help_outline_rounded;
      default:           return Icons.info_outline;
    }
  }

  Color _headerColor() {
    switch (cardType) {
      case _CardType.unverified: return AppTheme.warningOrange;
      case _CardType.verified:   return Colors.cyan;
      case _CardType.flagged:    return AppTheme.dangerRed;
      case _CardType.resolved:   return AppTheme.successGreen;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hColor = _headerColor();
    final gColor = _genuinityColor();
    final bool isAssigned = report.assignedUsers?.isNotEmpty == true ||
        report.assignedTeams?.isNotEmpty == true;
    final bool isSpam = report.predicted_category.toLowerCase() == 'spam';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: hColor.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: hColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              report.predicted_category.toUpperCase(),
                              style: TextStyle(color: hColor, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.8),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSpam) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppTheme.dangerRed, borderRadius: BorderRadius.circular(6)),
                              child: const Text('SPAM', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Report ID: ${report.id}',
                          style: const TextStyle(color: AppTheme.accentTeal, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                // Genuinity badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: gColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_genuinityIcon(), color: gColor, size: 14),
                      const SizedBox(width: 5),
                      Text(report.genuinityStatus.toUpperCase(),
                          style: TextStyle(color: gColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: AppTheme.textMediumContrast, size: 22),
                  onPressed: () => _showEditDialog(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Edit Metadata',
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                if (report.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(report.imageUrl!, width: 70, height: 70, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 70, height: 70, color: AppTheme.darkBackground,
                        child: const Icon(Icons.broken_image_outlined, color: AppTheme.textMediumContrast)),
                    ),
                  )
                else
                  Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(color: AppTheme.darkBackground, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.textMediumContrast.withOpacity(0.2))),
                    child: const Icon(Icons.image_outlined, color: AppTheme.textMediumContrast, size: 28),
                  ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.description, maxLines: 3, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 14, height: 1.4)),
                      const SizedBox(height: 10),
                      // Priority + upvote chips
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(color: AppTheme.dangerRed.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text('${report.priorityLabel.toUpperCase()} • ${report.priorityScore}',
                              style: const TextStyle(color: AppTheme.dangerRed, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        if ((report.upvoteCount ?? 1) > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(color: AppTheme.warningOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.people_alt_rounded, color: AppTheme.warningOrange, size: 13),
                              const SizedBox(width: 5),
                              Text('${report.upvoteCount} Reports', style: const TextStyle(color: AppTheme.warningOrange, fontSize: 11, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        // Status chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text('Status: ${report.status}', style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                      if (report.assignedUsers != null && report.assignedUsers!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.engineering_rounded, color: AppTheme.accentTeal, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Crew: ${report.assignedUsers!.map((u) => u['username']).join(', ')}',
                              style: const TextStyle(color: AppTheme.accentTeal, fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ],
                      if (report.address != null && report.address!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.location_on_rounded, color: AppTheme.textMediumContrast, size: 14),
                          const SizedBox(width: 6),
                          Expanded(child: Text(report.address!, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 12))),
                        ]),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Reported: ${_formatDate(report.createdAt)}',
                              style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 11)),
                          if (report.slaDeadline != null && report.status != 'Resolved')
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined, color: AppTheme.dangerRed, size: 12),
                                const SizedBox(width: 4),
                                Text('SLA: ${_formatDate(report.slaDeadline!)}',
                                    style: const TextStyle(color: AppTheme.dangerRed, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          if (report.slaDeadline != null && report.status == 'Resolved')
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 12),
                                const SizedBox(width: 4),
                                Text('SLA: ${_formatDate(report.slaDeadline!)}',
                                    style: const TextStyle(color: AppTheme.successGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── "Show all related" button ──────────────────────────────────────
          if ((report.upvoteCount ?? 1) > 1 || (report.reports != null && report.reports!.isNotEmpty)) ...[
            const Divider(color: AppTheme.darkBackground, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentTeal,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  ),
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: const Text('SHOW ALL RELATED REPORTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  onPressed: () => _showAllReportsDialog(context, report),
                ),
              ),
            ),
          ],

          // ── Action buttons ─────────────────────────────────────────────────
          if (cardType != _CardType.resolved && cardType != _CardType.flagged)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  // VERIFY — only on Unverified tab
                  if (cardType == _CardType.unverified) ...[
                    Expanded(
                      child: _actionBtn(
                        'VERIFY',
                        Icons.verified_rounded,
                        Colors.cyan,
                        () async {
                          await _api.editComplaint(report.id, {'genuinity_status': 'Verified'});
                          onRefresh();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // ASSIGN CREW / AUTO DISPATCH / RESOLVE — on Verified tab only
                  if (cardType == _CardType.verified) ...[
                    if (!isAssigned) ...[
                      // Not yet assigned: show manual assign + auto dispatch
                      Expanded(
                        child: _actionBtn(
                          'ASSIGN CREW',
                          Icons.engineering_rounded,
                          Colors.purpleAccent,
                          () => _showAssignDialog(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _autoDispatchBtn(context),
                      ),
                    ] else ...[
                      // Already assigned: show resolve
                      Expanded(
                        child: _actionBtn(
                          'RESOLVE',
                          Icons.check_circle_outline_rounded,
                          AppTheme.successGreen,
                          () async {
                            await _api.updateComplaintStatus(report.id, 'Resolved');
                            onRefresh();
                          },
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          // ── Remove Report — resolved spam only ──────────────────────────────
          if (cardType == _CardType.resolved &&
              report.predicted_category.toLowerCase() == 'spam')
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: _actionBtn(
                  'REMOVE REPORT',
                  Icons.delete_forever_rounded,
                  AppTheme.dangerRed,
                  () => _confirmAndDelete(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.15),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _autoDispatchBtn(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        try {
          final msg = await _api.autoAssignComplaint(report.id);
          onRefresh();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg,
                    style: const TextStyle(
                        color: AppTheme.textHighContrast,
                        fontWeight: FontWeight.bold)),
                backgroundColor: AppTheme.primaryBlue,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Auto-dispatch failed.'),
                  backgroundColor: AppTheme.dangerRed),
            );
          }
        }
      },
      icon: const Icon(Icons.send_rounded, size: 16),
      label: const Text('AUTO DISPATCH',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.dangerRed.withOpacity(0.15),
        foregroundColor: AppTheme.dangerRed,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  void _confirmAndDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppTheme.dangerRed, size: 24),
            SizedBox(width: 10),
            Text('Remove Spam Report'),
          ],
        ),
        content: Text(
          'This will permanently delete Report #${report.id} (${report.predicted_category.toUpperCase()}).\n\nThis action cannot be undone.',
          style: const TextStyle(color: AppTheme.textHighContrast, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteComplaint(report.id);
                onRefresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Spam report #${report.id} removed successfully.',
                        style: const TextStyle(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: AppTheme.successGreen,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to remove: $e', style: const TextStyle(color: Colors.white)),
                      backgroundColor: AppTheme.dangerRed,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('REMOVE', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAssignDialog(BuildContext context) async {
    final api = ApiService();
    List<Map<String, dynamic>> crewList = [];
    String? selectedUsername;
    bool loadingCrew = true;
    String? assignError;
    final String? suggestedDept = _suggestDepartment(report.predicted_category);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          if (loadingCrew) {
            api.listCrew(department: suggestedDept).then((list) {
              if (list.isEmpty) {
                api.listCrew().then((all) {
                  setDlgState(() { crewList = all; loadingCrew = false; });
                }).catchError((e) {
                  setDlgState(() { loadingCrew = false; assignError = e.toString(); });
                });
              } else {
                setDlgState(() { crewList = list; loadingCrew = false; });
              }
            }).catchError((e) {
              setDlgState(() { loadingCrew = false; assignError = e.toString(); });
            });
          }

          return AlertDialog(
            title: const Text('Assign to Crew'),
            content: loadingCrew
                ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
                : assignError != null
                    ? Text(assignError!, style: const TextStyle(color: AppTheme.dangerRed))
                    : crewList.isEmpty
                        ? const Text('No crew members registered yet.', style: TextStyle(color: AppTheme.textMediumContrast))
                        : DropdownButtonFormField<String>(
                            value: selectedUsername,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Select Crew Member'),
                            items: crewList.map((c) => DropdownMenuItem<String>(
                              value: c['username'] as String,
                              child: Text(c['username'] as String),
                            )).toList(),
                            onChanged: (v) => setDlgState(() => selectedUsername = v),
                          ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              if (!loadingCrew && selectedUsername != null)
                ElevatedButton(
                  onPressed: () async {
                    await api.assignComplaint(report.id, selectedUsername!);
                    if (ctx.mounted) Navigator.pop(ctx);
                    onRefresh();
                  },
                  child: const Text('DISPATCH'),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    String selectedCategory = report.predicted_category;
    String selectedPriority = report.priorityLabel;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Edit Metadata'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: {selectedCategory, 'Road Issue', 'Garbage Overflow', 'Streetlight Issue', 'General'}
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setDlgState(() => selectedCategory = v!),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: selectedPriority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: {selectedPriority, 'Low', 'Medium', 'High', 'Critical'}
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setDlgState(() => selectedPriority = v!),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () { Navigator.pop(ctx); _showAssignDialog(context); },
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('REASSIGN CREW'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue.withOpacity(0.15),
                  foregroundColor: AppTheme.primaryBlue,
                ),
              ),
              if (report.status == 'Assigned' || report.status == 'In-Progress') ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _showManageCrewDialog(context, report); },
                  icon: const Icon(Icons.people_alt_rounded),
                  label: const Text('MANAGE TEAM'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal.withOpacity(0.15),
                    foregroundColor: AppTheme.accentTeal,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _api.editComplaint(report.id, {
                    'predicted_category': selectedCategory,
                    'priority_label': selectedPriority,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  onRefresh();
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  String? _suggestDepartment(String category) {
    final c = category.toLowerCase();
    if (c.contains('pothole') || c.contains('road')) return 'ROAD';
    if (c.contains('garbage') || c.contains('waste')) return 'SANITATION';
    if (c.contains('light') || c.contains('electric')) return 'ELECTRICAL';
    return null;
  }

  void _showManageCrewDialog(BuildContext context, Complaint issue) async {
    List<Map<String, dynamic>> allCrew = [];
    bool diaLoading = true;
    final suggestedDept = _suggestDepartment(issue.predicted_category);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDiaState) {
          if (diaLoading && allCrew.isEmpty) {
            _api.listCrewMembers().then((list) {
              setDiaState(() {
                allCrew = suggestedDept != null
                    ? list.where((c) => c['department'] == suggestedDept).toList()
                    : list;
                diaLoading = false;
              });
            });
          }

          return AlertDialog(
            title: Text('Manage Crew', style: Theme.of(context).textTheme.titleLarge),
            content: SizedBox(
              width: double.maxFinite,
              child: diaLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CURRENTLY ASSIGNED', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMediumContrast)),
                          const SizedBox(height: 12),
                          if (issue.assignedUsers == null || issue.assignedUsers!.isEmpty)
                            const Text('No individual members assigned.', style: TextStyle(color: AppTheme.textMediumContrast, fontSize: 13))
                          else
                            ...issue.assignedUsers!.map((u) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(backgroundColor: AppTheme.primaryBlue, radius: 16,
                                  child: Text(u['username'][0].toUpperCase(), style: const TextStyle(fontSize: 14, color: AppTheme.textHighContrast))),
                              title: Text(u['username'], style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 15)),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: AppTheme.dangerRed, size: 24),
                                onPressed: () async {
                                  await _api.manageCrewAssignment(complaintId: issue.id, action: 'remove', userId: u['id']);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  onRefresh();
                                },
                              ),
                            )),
                          const Divider(height: 32),
                          Text('ADD PERSONNEL (${suggestedDept ?? "ALL"})',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMediumContrast)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: ListView.builder(
                              itemCount: allCrew.length,
                              itemBuilder: (context, index) {
                                final crew = allCrew[index];
                                final isAlreadyAssigned = issue.assignedUsers?.any((u) => u['id'] == crew['id']) ?? false;
                                if (isAlreadyAssigned) return const SizedBox.shrink();
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.person_add_outlined, color: AppTheme.accentTeal, size: 24),
                                  title: Text(crew['username'], style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 15)),
                                  subtitle: Text(crew['department'] ?? '', style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 13)),
                                  onTap: () async {
                                    await _api.manageCrewAssignment(complaintId: issue.id, action: 'add', userId: crew['id']);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    onRefresh();
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  void _showAllReportsDialog(BuildContext context, Complaint report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('All Submissions'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: FutureBuilder<Complaint>(
            future: _api.getComplaint(report.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppTheme.dangerRed)));
              }
              final detailedComplaint = snapshot.data;
              final reports = detailedComplaint?.reports ?? [];
              if (reports.isEmpty) {
                return const Center(child: Text('No individual reports found.', style: TextStyle(color: AppTheme.textMediumContrast)));
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final sub = reports[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.textMediumContrast.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (sub.imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(sub.imageUrl!, width: 50, height: 50, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(width: 50, height: 50, color: AppTheme.cardBackground,
                                child: const Icon(Icons.broken_image_outlined, color: AppTheme.textMediumContrast, size: 24)),
                            ),
                          )
                        else
                          Container(width: 50, height: 50,
                            decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.image_outlined, color: AppTheme.textMediumContrast, size: 24)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('@${sub.username ?? "Citizen"}',
                                      style: const TextStyle(color: AppTheme.accentTeal, fontSize: 14, fontWeight: FontWeight.bold)),
                                  Text(sub.createdAt.toLocal().toString().split(' ')[0],
                                      style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(sub.description, maxLines: 3, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 14, height: 1.4)),
                              if (sub.address != null && sub.address!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Icon(Icons.location_on_rounded, color: AppTheme.textMediumContrast, size: 14),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(sub.address!, maxLines: 2, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 13)),
                                  ),
                                ]),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
