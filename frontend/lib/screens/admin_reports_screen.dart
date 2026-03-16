import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key, this.title = 'ALL REPORTS'});
  final String title;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _api = ApiService();
  bool _loading = true;
  bool _showAllSubmissions = false;
  List<Complaint> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final reports = await _api.getComplaints(allSubmissions: _showAllSubmissions);
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
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _showAllSubmissions = !_showAllSubmissions;
              });
              _loadData();
            },
            icon: Icon(
              _showAllSubmissions ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
              color: _showAllSubmissions ? Colors.amberAccent : Colors.white
            ),
            tooltip: _showAllSubmissions ? 'Show Unique Issues' : 'Show All Submissions',
          ),
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
                      itemBuilder: (context, idx) {
                        final report = _reports[idx];
                        if (_showAllSubmissions) {
                          return _UserReportCard(report: report, onRefresh: _loadData);
                        }
                        return _AdminReportCard(
                          report: report,
                          onRefresh: _loadData,
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

class _AdminReportCard extends StatelessWidget {
  _AdminReportCard({required this.report, required this.onRefresh});
  final Complaint report;
  final VoidCallback onRefresh;
  final _api = ApiService();

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
    final bool isAssigned = report.assignedUsers?.isNotEmpty == true || report.assignedTeams?.isNotEmpty == true;
    
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
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                report.predicted_category.toUpperCase(),
                                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (report.predicted_category == 'Spam')
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                                child: const Text('SPAM REPORT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                        child: Text(report.status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: Colors.white70, size: 20),
                        onPressed: () => _showEditDialog(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Edit Metadata',
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
                            const SizedBox(height: 8),
                            // Priority Score Wrap
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${report.priorityLabel.toUpperCase()} • ${report.priorityScore}',
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if ((report.upvoteCount ?? 1) > 1)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.people_alt_rounded, color: Colors.orangeAccent, size: 10),
                                        const SizedBox(width: 4),
                                        Text('${report.upvoteCount} Reports', style: const TextStyle(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Crew Info
                            if (report.assignedUsers != null && report.assignedUsers!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.engineering_rounded, color: Colors.tealAccent, size: 12),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Crew: ${report.assignedUsers!.map((u) => u['username'].split('_')[0]).join(", ")}',
                                        style: TextStyle(color: Colors.tealAccent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                
                // Nested Reports List (Duplicate & Original Submissions)
                // Nested Reports List Button
                if ((report.upvoteCount ?? 1) > 1 || (report.reports != null && report.reports!.isNotEmpty)) ...[
                  const Divider(color: Colors.white10, height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.tealAccent,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.list_alt_rounded, size: 16),
                        label: const Text('SHOW ALL REPORTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                        onPressed: () => _showAllReportsDialog(context, report),
                      ),
                    ),
                  ),
                ],
                
                // Actions
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
                      if (report.status == 'Reported' || report.status == 'Verified')
                        const SizedBox(width: 10),
                      if (report.status != 'Resolved')
                        Expanded(
                          child: _actionBtn(
                              'ASSIGN CREW',
                              Icons.engineering_rounded,
                              Colors.purpleAccent,
                              () => _showAssignDialog(context)),
                        ),
                      if (report.status != 'Resolved' && isAssigned)
                        const SizedBox(width: 10),
                      if (report.status != 'Resolved' && isAssigned)
                        Expanded(
                          child: _actionBtn(
                              'RESOLVE',
                              Icons.check_circle_outline_rounded,
                              Colors.tealAccent,
                              () async {
                                await ApiService().updateComplaintStatus(report.id, 'Resolved');
                                onRefresh();
                              }),
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
              title: const Text('Assign to Crew', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
                                child: Text(c['username'] as String),
                              )).toList(),
                              onChanged: (v) => setDlgState(() => selectedUsername = v),
                            ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
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
            ),
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
        builder: (ctx, setDlgState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Colors.indigo.shade900.withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white24)),
            title: const Text('Edit Metadata', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  dropdownColor: Colors.indigo.shade900,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: Colors.white54)),
                  items: {selectedCategory, 'Road Issue', 'Garbage Overflow', 'Streetlight Issue', 'General'}
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setDlgState(() => selectedCategory = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  dropdownColor: Colors.indigo.shade900,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Priority', labelStyle: TextStyle(color: Colors.white54)),
                  items: {selectedPriority, 'Low', 'Medium', 'High', 'Critical'}
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setDlgState(() => selectedPriority = v!),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showAssignDialog(context);
                  },
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('REASSIGN CREW'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent.withOpacity(0.1),
                    foregroundColor: Colors.purpleAccent,
                  ),
                ),
                if (report.status == 'Assigned' || report.status == 'In-Progress') ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showManageCrewDialog(context, report);
                    },
                    icon: const Icon(Icons.people_alt_rounded, size: 16),
                    label: const Text('MANAGE TEAM'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent.withOpacity(0.1),
                      foregroundColor: Colors.tealAccent,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
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
                if (suggestedDept != null) {
                  allCrew = list.where((c) => c['department'] == suggestedDept).toList();
                } else {
                  allCrew = list;
                }
                diaLoading = false;
              });
            });
          }

          return AlertDialog(
            backgroundColor: Colors.indigo.shade900,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Manage Crew - Issue #${issue.id}', style: const TextStyle(color: Colors.white, fontSize: 16)),
            content: SizedBox(
              width: double.maxFinite,
              child: diaLoading 
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CURRENTLY ASSIGNED', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (issue.assignedUsers == null || issue.assignedUsers!.isEmpty)
                          const Text('No individual members assigned.', style: TextStyle(color: Colors.white30, fontSize: 11))
                        else
                          ...issue.assignedUsers!.map((u) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(radius: 12, child: Text(u['username'][0].toUpperCase(), style: const TextStyle(fontSize: 10))),
                            title: Text(u['username'], style: const TextStyle(color: Colors.white, fontSize: 13)),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                              onPressed: () async {
                                await _api.manageCrewAssignment(complaintId: issue.id, action: 'remove', userId: u['id']);
                                Navigator.pop(ctx);
                                onRefresh();
                              },
                            ),
                          )),
                        const Divider(color: Colors.white10, height: 24),
                        Text('ADD personnel (${suggestedDept ?? "ALL"})', style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          height: 150,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: allCrew.length,
                            itemBuilder: (context, index) {
                              final crew = allCrew[index];
                              final isAlreadyAssigned = issue.assignedUsers?.any((u) => u['id'] == crew['id']) ?? false;
                              if (isAlreadyAssigned) return const SizedBox.shrink();

                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.person_add_outlined, color: Colors.tealAccent, size: 18),
                                title: Text(crew['username'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                subtitle: Text(crew['department'] ?? '', style: const TextStyle(color: Colors.white30, fontSize: 10)),
                                onTap: () async {
                                  await _api.manageCrewAssignment(complaintId: issue.id, action: 'add', userId: crew['id']);
                                  Navigator.pop(ctx);
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
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.indigo.shade900.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white24)),
          title: const Text('All Submissions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: FutureBuilder<Complaint>(
              future: _api.getComplaint(report.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                }

                final detailedComplaint = snapshot.data;
                final reports = detailedComplaint?.reports ?? [];

                if (reports.isEmpty) {
                  return const Center(child: Text('No individual reports found.', style: TextStyle(color: Colors.white54)));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final sub = reports[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (sub.imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(sub.imageUrl!, width: 40, height: 40, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 40, height: 40, color: Colors.white10,
                                  child: const Icon(Icons.broken_image_outlined, color: Colors.white24, size: 20)),
                              ),
                            )
                          else
                            Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.image_outlined, color: Colors.white24, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '@${sub.username ?? 'Citizen'}',
                                      style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      "${sub.createdAt.toLocal().toString().split(' ')[0]}",
                                      style: const TextStyle(color: Colors.white30, fontSize: 10)
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sub.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                                ),
                                if (sub.address != null && sub.address!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_rounded, color: Colors.white24, size: 10),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          sub.address!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ]
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
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const Text('Close', style: TextStyle(color: Colors.white54))
            ),
          ],
        ),
      ),
    );
  }
}

class _UserReportCard extends StatelessWidget {
  const _UserReportCard({required this.report, required this.onRefresh});
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
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(report.imageUrl!, width: 60, height: 60, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: Colors.white10,
                        child: const Icon(Icons.broken_image_outlined, color: Colors.white24)),
                    ),
                  )
                else
                  Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.image_outlined, color: Colors.white24)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                report.predicted_category.toUpperCase(),
                                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                              ),
                              if (report.predicted_category == 'Spam')
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('SPAM', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                            child: Text(report.status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(report.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
                      const SizedBox(height: 8),
                      if (report.address != null && report.address!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: Colors.white30, size: 10),
                            const SizedBox(width: 4),
                            Expanded(child: Text(report.address!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10))),
                          ],
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            report.isOriginal ? Icons.fiber_new_rounded : Icons.content_copy_rounded, 
                            color: report.isOriginal ? Colors.amberAccent : Colors.white54, 
                            size: 12
                          ),
                          const SizedBox(width: 4),
                          Text(
                            report.isOriginal ? "Original Reporter" : "Duplicate Reporter",
                            style: TextStyle(
                              color: report.isOriginal ? Colors.amberAccent : Colors.white54,
                              fontSize: 10,
                              fontWeight: report.isOriginal ? FontWeight.bold : FontWeight.normal
                            )
                          ),
                          const Spacer(),
                          Text(
                            "${report.createdAt.toLocal().toString().split(' ')[0]} ${report.createdAt.toLocal().toString().split(' ')[1].substring(0, 5)}",
                            style: const TextStyle(color: Colors.white54, fontSize: 9),
                          )
                        ],
                      )
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
}
