import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _stats;
  List<Complaint>? _highPriorityQueue;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final stats = await _api.getAdminStats();
      final highPriority = await _api.getHighPriorityIssues();
      if (mounted) {
        setState(() {
          _stats = stats;
          _highPriorityQueue = highPriority;
        });
      }
    } catch (e) {
      if (mounted) {
        _errorMessage = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading admin dashboard')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('IPUMS COMMAND CENTER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16)),
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
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _errorMessage != null
              ? SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                          const SizedBox(height: 12),
                          const Text(
                            'Unable to load admin dashboard.',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('RETRY'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SLA Warning Strip
                    if ((_stats!['sla_breaches'] ?? 0) > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'SLA ALERT: ${_stats!['sla_breaches']} issues open > 3 days',
                                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const Text('LIVE KPIs', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(height: 16),
                    
                    // Main Stats Grid
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.5,
                      children: [
                        _buildGlassStatCard('ACTIVE ISSUES', _stats!['active_reports']?.toString() ?? '0', Icons.warning_rounded, Colors.orangeAccent),
                        _buildGlassStatCard('RESOLVED', _stats!['resolved_reports']?.toString() ?? '0', Icons.task_alt_rounded, Colors.tealAccent),
                        _buildGlassStatCard('AVG FIX TIME', _stats!['avg_resolution_days'] != null ? '${_stats!['avg_resolution_days']} d' : '-', Icons.timer_rounded, Colors.blueAccent),
                        _buildGlassStatCard('CREW READY', _stats!['crew_available']?.toString() ?? '0', Icons.engineering_rounded, Colors.purpleAccent),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // High Priority Queue
                    Row(
                      children: [
                        const Text('🚨 URGENT QUEUE', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                          child: Text('${_highPriorityQueue?.length ?? 0}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (_highPriorityQueue == null || _highPriorityQueue!.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text('No urgent issues pending', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                        ),
                      )
                    else
                      ..._highPriorityQueue!.map((issue) => _buildUrgentIssueCard(issue)),
                      
                    const SizedBox(height: 32),

                    // Top Categories Mini-Chart
                    const Text('TOP ISSUES', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(height: 16),
                    _buildTopCategoriesPane(),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildGlassStatCard(String label, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 20),
                  Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              const Spacer(),
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrgentIssueCard(Complaint issue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.predicted_category.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: Colors.white30, size: 10),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              issue.address ?? 'Coordinates Captured',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(height: 8),
                      // Priority and upvotes (Wrapped to prevent overflow)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Score: ${issue.priorityScore} (${issue.priorityLabel.toUpperCase()})',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          if (issue.upvoteCount != null && issue.upvoteCount! > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '🔥 ${issue.upvoteCount} Reports',
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      issue.status,
                      style: TextStyle(color: Colors.orangeAccent.withOpacity(0.8), fontSize: 10),
                    ),
                    const SizedBox(height: 8),
                    if (issue.status == 'Assigned' || issue.status == 'In-Progress')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.teal.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              issue.assignedTeams?.isNotEmpty == true 
                                ? issue.assignedTeams![0]['name']
                                : 'Assigned',
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.tealAccent, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                            if (issue.assignedTeams?.isNotEmpty == true && issue.assignedTeams![0]['members'] != null)
                              Text(
                                (issue.assignedTeams![0]['members'] as List).join(', '),
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.tealAccent.withOpacity(0.6), fontSize: 8),
                              ),
                          ],
                        ),
                      )
                    else if (issue.assignedUsers != null && issue.assignedUsers!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'DETAILED CREW',
                              style: TextStyle(color: Colors.indigoAccent.shade100, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              issue.assignedUsers!.map((u) => u['username'].split('_')[0]).join(', ').toUpperCase(),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              final msg = await _api.autoAssignComplaint(issue.id);
                              _loadData();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    backgroundColor: Colors.teal.shade700,
                                    duration: const Duration(seconds: 4),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Auto-assign failed: $e'), backgroundColor: Colors.redAccent),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.15),
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('AUTO DISPATCH'),
                        ),
                      ),
                    if (issue.status == 'Assigned' || issue.status == 'In-Progress')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          height: 24,
                          child: TextButton(
                            onPressed: () => _showManageCrewDialog(issue),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              backgroundColor: Colors.indigoAccent.withOpacity(0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('MANAGE TEAM', style: TextStyle(color: Colors.indigoAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopCategoriesPane() {
    final tops = _stats!['top_categories'] as List<dynamic>? ?? [];
    if (tops.isEmpty) return const SizedBox.shrink();
    
    final maxCount = tops.fold<int>(0, (max, item) => (item['count'] as int) > max ? (item['count'] as int) : max);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: tops.map((cat) {
              final count = cat['count'] as int;
              final pct = maxCount > 0 ? count / maxCount : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cat['predicted_category'], style: const TextStyle(color: Colors.white, fontSize: 12)),
                        Text('$count', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      color: Colors.tealAccent,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
  void _showManageCrewDialog(Complaint issue) async {
    List<Map<String, dynamic>> allCrew = [];
    bool diaLoading = true;
    
    // Suggest department based on category
    final suggestedDept = _suggestDepartment(issue.predicted_category);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDiaState) {
          if (diaLoading && allCrew.isEmpty) {
            _api.listCrewMembers().then((list) {
              setDiaState(() {
                // Filter by suggested department for professionalism
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
                          const Text('No individual members assigned yet.', style: TextStyle(color: Colors.white30, fontSize: 11))
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
                                _loadData();
                              },
                            ),
                          )),
                        const Divider(color: Colors.white10, height: 24),
                        const Text('ADD EXTRA PERSONNEL', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          height: 150,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: allCrew.length,
                            itemBuilder: (context, index) {
                              final crew = allCrew[index];
                              final isAssigned = issue.assignedUsers?.any((u) => u['id'] == crew['id']) ?? false;
                              if (isAssigned) return const SizedBox.shrink();

                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.person_add_outlined, color: Colors.tealAccent, size: 18),
                                title: Text(crew['username'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                subtitle: Text(crew['department'] ?? '', style: const TextStyle(color: Colors.white30, fontSize: 10)),
                                onTap: () async {
                                  await _api.manageCrewAssignment(complaintId: issue.id, action: 'add', userId: crew['id']);
                                  Navigator.pop(ctx);
                                  _loadData();
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

  /// Helper to map category to department
  String? _suggestDepartment(String category) {
    final c = category.toLowerCase();
    if (c.contains('road') || c.contains('pothole')) return 'ROAD';
    if (c.contains('garbage') || c.contains('waste') || c.contains('sanit')) return 'SANITATION';
    if (c.contains('light') || c.contains('electric') || c.contains('power')) return 'ELECTRICAL';
    return null;
  }
}
