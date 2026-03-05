import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Complaint> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('ALL REPORTS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
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
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
              : _reports.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text('No reports yet', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                      ],
                    ))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: _reports.length,
                      itemBuilder: (context, idx) => _AdminReportCard(
                        report: _reports[idx],
                        onRefresh: _loadData,
                      ),
                    ),
        ),
      ),
    );
  }
}

class _AdminReportCard extends StatelessWidget {
  const _AdminReportCard({required this.report, required this.onRefresh});
  final Complaint report;
  final VoidCallback onRefresh;

  Color _statusColor(String s) {
    switch (s) {
      case 'Reported': return Colors.blueAccent;
      case 'Verified': return Colors.cyanAccent;
      case 'Assigned': return Colors.purpleAccent;
      case 'In-Progress': return Colors.orangeAccent;
      case 'Resolved': return Colors.tealAccent;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(report.status);
    final bool isAssigned = report.assignedCrew != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.predicted_category.toUpperCase(),
                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                        child: Text(report.status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (report.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(report.imageUrl!, width: 55, height: 55, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(width: 55, height: 55, color: Colors.white10,
                              child: const Icon(Icons.broken_image_outlined, color: Colors.white24)),
                          ),
                        )
                      else
                        Container(width: 55, height: 55, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.image_outlined, color: Colors.white24)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(report.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${report.priorityLabel.toUpperCase()} • ${report.priorityScore}',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if ((report.upvoteCount ?? 1) > 1)
                                  Row(
                                    children: [
                                      const Icon(Icons.people_alt_rounded, color: Colors.orangeAccent, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${report.upvoteCount} reports',
                                        style: const TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (isAssigned && report.assignedCrewName != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.engineering_rounded, color: Colors.purpleAccent, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Assigned to: ${report.assignedCrewName}',
                                      style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            if (report.address != null && report.address!.isNotEmpty)
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, color: Colors.white24, size: 12),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(report.address!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      if (report.status == 'Reported')
                        Expanded(
                          child: _actionBtn('VERIFY', Icons.verified_rounded, Colors.cyanAccent, () async {
                            await ApiService().updateComplaintStatus(report.id, 'Verified');
                            onRefresh();
                          }),
                        ),
                      if (report.status == 'Reported') const SizedBox(width: 10),
                      if (report.status != 'Resolved')
                        Expanded(
                          child: _actionBtn(
                              isAssigned ? 'REASSIGN CREW' : 'ASSIGN CREW',
                              Icons.engineering_rounded,
                              Colors.purpleAccent,
                              () => _showAssignDialog(context)),
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
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.12),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.3))),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  void _showAssignDialog(BuildContext context) async {
    final api = ApiService();
    List<Map<String, dynamic>> crewList = [];
    String? selectedUsername;
    bool loadingCrew = true;
    String? assignError;

    // Get the matching department from predicted category
    String? suggestedDept = _suggestDepartment(report.predicted_category);

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

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              backgroundColor: Colors.indigo.shade900.withOpacity(0.95),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white24)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Assign to Crew', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  if (suggestedDept != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Suggested: $suggestedDept dept', style: const TextStyle(color: Colors.tealAccent, fontSize: 11)),
                    ),
                ],
              ),
              content: loadingCrew
                  ? const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: Colors.tealAccent)))
                  : assignError != null
                      ? Text(assignError!, style: const TextStyle(color: Colors.redAccent))
                      : crewList.isEmpty
                          ? const Text('No crew members registered yet.', style: TextStyle(color: Colors.white54))
                          : DropdownButtonFormField<String>(
                              value: selectedUsername,
                              isExpanded: true,
                              dropdownColor: Colors.indigo.shade900,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: 'Select Crew Member',
                                labelStyle: TextStyle(color: Colors.white54),
                                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                              ),
                              items: crewList.map((c) => DropdownMenuItem<String>(
                                value: c['username'] as String,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(c['username'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(c['department'] ?? 'No dept', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                  ],
                                ),
                              )).toList(),
                              onChanged: (v) => setDlgState(() => selectedUsername = v),
                            ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                if (!loadingCrew && selectedUsername != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      await api.assignComplaint(report.id, selectedUsername!);
                      if (ctx.mounted) Navigator.pop(ctx);
                      onRefresh();
                    },
                    child: const Text('DISPATCH'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Map AI category to department code
  String? _suggestDepartment(String category) {
    final c = category.toLowerCase();
    if (c.contains('pothole') || c.contains('road') || c.contains('pavement')) return 'ROAD';
    if (c.contains('garbage') || c.contains('waste') || c.contains('sanit')) return 'SANITATION';
    if (c.contains('light') || c.contains('electric') || c.contains('power')) return 'ELECTRICAL';
    if (c.contains('water') || c.contains('drain') || c.contains('flood')) return 'WATER';
    if (c.contains('park') || c.contains('tree') || c.contains('garden')) return 'PARKS';
    return null;
  }
}
