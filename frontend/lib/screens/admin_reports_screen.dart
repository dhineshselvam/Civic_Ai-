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
      appBar: AppBar(
        title: Text(widget.title),
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
              color: _showAllSubmissions ? AppTheme.warningOrange : AppTheme.textHighContrast
            ),
            tooltip: _showAllSubmissions ? 'Show Unique Issues' : 'Show All Submissions',
          ),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _reports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 80, color: AppTheme.textMediumContrast.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('No reports found', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.textMediumContrast)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemCount: _reports.length,
                    itemBuilder: (context, idx) {
                      final report = _reports[idx];
                      if (_showAllSubmissions) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _UserReportCard(report: report, onRefresh: _loadData),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _AdminReportCard(report: report, onRefresh: _loadData),
                      );
                    },
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
      case 'Reported': return AppTheme.primaryBlue;
      case 'Verified': return Colors.cyan;
      case 'Assigned': return Colors.purpleAccent;
      case 'In-Progress': return AppTheme.warningOrange;
      case 'Resolved': return AppTheme.successGreen;
      default: return AppTheme.textMediumContrast;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return "Today";
    if (diff.inDays == 1) return "Yesterday";
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(report.status);
    final bool isAssigned = report.assignedUsers?.isNotEmpty == true || report.assignedTeams?.isNotEmpty == true;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.textMediumContrast.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          report.predicted_category.toUpperCase(),
                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.8),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (report.predicted_category.toLowerCase() == 'spam')
                        Container(
                          margin: const EdgeInsets.only(left: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.dangerRed, borderRadius: BorderRadius.circular(6)),
                          child: const Text('SPAM ALERT', style: TextStyle(color: AppTheme.textHighContrast, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: Text(report.status.toUpperCase(), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: AppTheme.textMediumContrast, size: 24),
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
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    decoration: BoxDecoration(color: AppTheme.darkBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.textMediumContrast.withOpacity(0.2))),
                    child: const Icon(Icons.image_outlined, color: AppTheme.textMediumContrast, size: 28),
                  ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.description, maxLines: 3, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 15, height: 1.4)),
                      const SizedBox(height: 12),
                      
                      // Priority Score Wrap
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerRed.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${report.priorityLabel.toUpperCase()} • ${report.priorityScore}',
                              style: const TextStyle(color: AppTheme.dangerRed, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if ((report.upvoteCount ?? 1) > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.warningOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.people_alt_rounded, color: AppTheme.warningOrange, size: 14),
                                  const SizedBox(width: 6),
                                  Text('${report.upvoteCount} Reports', style: const TextStyle(color: AppTheme.warningOrange, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Crew Info
                      if (report.assignedUsers != null && report.assignedUsers!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.engineering_rounded, color: AppTheme.accentTeal, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Crew: ${report.assignedUsers!.map((u) => u['username'].split('_')[0]).join(", ")}',
                                  style: const TextStyle(color: AppTheme.accentTeal, fontSize: 13, fontWeight: FontWeight.w600),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (report.address != null && report.address!.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppTheme.textMediumContrast, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(report.address!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 13))),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Text("Registered: ${_formatDate(report.createdAt)}", style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Nested Reports List Button
          if ((report.upvoteCount ?? 1) > 1 || (report.reports != null && report.reports!.isNotEmpty)) ...[
            const Divider(color: AppTheme.darkBackground, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentTeal,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  icon: const Icon(Icons.list_alt_rounded, size: 20),
                  label: const Text('SHOW ALL RELATED REPORTS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  onPressed: () => _showAllReportsDialog(context, report),
                ),
              ),
            ),
          ],
          
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                if (report.status == 'Reported')
                  Expanded(
                    child: _actionBtn('VERIFY', Icons.verified_rounded, Colors.cyan, () async {
                      await ApiService().updateComplaintStatus(report.id, 'Verified');
                      onRefresh();
                    }),
                  ),
                if (report.status == 'Reported' || report.status == 'Verified')
                  const SizedBox(width: 16),
                if (report.status != 'Resolved')
                  Expanded(
                    child: _actionBtn(
                        'ASSIGN CREW',
                        Icons.engineering_rounded,
                        Colors.purpleAccent,
                        () => _showAssignDialog(context)),
                  ),
                if (report.status != 'Resolved' && isAssigned)
                  const SizedBox(width: 16),
                if (report.status != 'Resolved' && isAssigned)
                  Expanded(
                    child: _actionBtn(
                        'RESOLVE',
                        Icons.check_circle_outline_rounded,
                        AppTheme.successGreen,
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
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.15),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
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
                            decoration: const InputDecoration(
                              labelText: 'Select Crew Member',
                            ),
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
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAssignDialog(context);
                },
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
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showManageCrewDialog(context, report);
                  },
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
                            leading: CircleAvatar(backgroundColor: AppTheme.primaryBlue, radius: 16, child: Text(u['username'][0].toUpperCase(), style: const TextStyle(fontSize: 14, color: AppTheme.textHighContrast))),
                            title: Text(u['username'], style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 15)),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppTheme.dangerRed, size: 24),
                              onPressed: () async {
                                await _api.manageCrewAssignment(complaintId: issue.id, action: 'remove', userId: u['id']);
                                Navigator.pop(ctx);
                                onRefresh();
                              },
                            ),
                          )),
                        const Divider(height: 32),
                        Text('ADD PERSONNEL (${suggestedDept ?? "ALL"})', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMediumContrast)),
                        const SizedBox(height: 12),
                        Container(
                          height: 200,
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
                                leading: const Icon(Icons.person_add_outlined, color: AppTheme.accentTeal, size: 24),
                                title: Text(crew['username'], style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 15)),
                                subtitle: Text(crew['department'] ?? '', style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 13)),
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
                          Container(width: 50, height: 50, decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.image_outlined, color: AppTheme.textMediumContrast, size: 24)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '@${sub.username ?? 'Citizen'}',
                                    style: const TextStyle(color: AppTheme.accentTeal, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "${sub.createdAt.toLocal().toString().split(' ')[0]}",
                                    style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 12)
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                sub.description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 14, height: 1.4),
                              ),
                              if (sub.address != null && sub.address!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on_rounded, color: AppTheme.textMediumContrast, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        sub.address!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 13),
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
            child: const Text('Close')
          ),
        ],
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
      case 'Reported': return AppTheme.primaryBlue;
      case 'Verified': return Colors.cyan;
      case 'Assigned': return Colors.purpleAccent;
      case 'In-Progress': return AppTheme.warningOrange;
      case 'Resolved': return AppTheme.successGreen;
      default: return AppTheme.textMediumContrast;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(report.status);
    
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (report.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(report.imageUrl!, width: 70, height: 70, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 70, height: 70, color: AppTheme.darkBackground,
                    child: const Icon(Icons.broken_image_outlined, color: AppTheme.textMediumContrast)),
                ),
              )
            else
              Container(width: 70, height: 70, decoration: BoxDecoration(color: AppTheme.darkBackground, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.image_outlined, color: AppTheme.textMediumContrast)),
            const SizedBox(width: 20),
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
                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                          ),
                          if (report.predicted_category.toLowerCase() == 'spam')
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.dangerRed, borderRadius: BorderRadius.circular(4)),
                              child: const Text('SPAM', style: TextStyle(color: AppTheme.textHighContrast, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                        child: Text(report.status.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(report.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 12),
                  if (report.address != null && report.address!.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppTheme.textMediumContrast, size: 14),
                        const SizedBox(width: 6),
                        Expanded(child: Text(report.address!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 13))),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        report.isOriginal ? Icons.fiber_new_rounded : Icons.content_copy_rounded, 
                        color: report.isOriginal ? AppTheme.warningOrange : AppTheme.textMediumContrast, 
                        size: 16
                      ),
                      const SizedBox(width: 6),
                      Text(
                        report.isOriginal ? "Original Reporter" : "Duplicate Reporter",
                        style: TextStyle(
                          color: report.isOriginal ? AppTheme.warningOrange : AppTheme.textMediumContrast,
                          fontSize: 12,
                          fontWeight: report.isOriginal ? FontWeight.bold : FontWeight.normal
                        )
                      ),
                      const Spacer(),
                      Text(
                        "${report.createdAt.toLocal().toString().split(' ')[0]} ${report.createdAt.toLocal().toString().split(' ')[1].substring(0, 5)}",
                        style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 12),
                      )
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
