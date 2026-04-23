import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error loading admin dashboard')));
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
      appBar: AppBar(
        title: const Text('IPUMS COMMAND CENTER'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Unable to load dashboard',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('RETRY'),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SLA Warning Strip
                        if ((_stats!['sla_breaches'] ?? 0) > 0)
                          Container(
                            margin: const EdgeInsets.only(bottom: 32),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerRed.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.dangerRed.withOpacity(0.5), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed, size: 28),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'SLA ALERT: ${_stats!['sla_breaches']} issues open > 3 days',
                                    style: const TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        Text('LIVE KPIs', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textMediumContrast)),
                        const SizedBox(height: 16),
                        
                        // Main Stats Grid
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.4,
                          children: [
                            _buildGlassStatCard('ACTIVE ISSUES', _stats!['active_reports']?.toString() ?? '0', Icons.warning_rounded, AppTheme.warningOrange),
                            _buildGlassStatCard('RESOLVED', _stats!['resolved_reports']?.toString() ?? '0', Icons.task_alt_rounded, AppTheme.successGreen),
                            _buildGlassStatCard('AVG FIX TIME', _stats!['avg_resolution_days'] != null ? '${_stats!['avg_resolution_days']} d' : '-', Icons.timer_rounded, AppTheme.accentTeal),
                            _buildGlassStatCard('CREW READY', _stats!['crew_available']?.toString() ?? '0', Icons.engineering_rounded, Colors.purpleAccent),
                          ],
                        ),
                        
                        const SizedBox(height: 48),
                        
                        // High Priority Queue
                        Row(
                          children: [
                            Text('🚨 URGENT QUEUE', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textMediumContrast)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.dangerRed.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                '${_highPriorityQueue?.length ?? 0}', 
                                style: const TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.bold, fontSize: 14)
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        if (_highPriorityQueue == null || _highPriorityQueue!.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text('No urgent issues pending', style: Theme.of(context).textTheme.bodyMedium),
                            ),
                          )
                        else
                          ..._highPriorityQueue!.map((issue) => _buildUrgentIssueCard(issue)),
                          
                        const SizedBox(height: 48),

                        // Top Categories Mini-Chart
                        Text('TOP ISSUES', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textMediumContrast)),
                        const SizedBox(height: 16),
                        _buildTopCategoriesPane(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildGlassStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast)),
              ],
            ),
            const Spacer(),
            Text(label, style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentIssueCard(Complaint issue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.dangerRed.withOpacity(0.4), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Align to top
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.dangerRed.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.warning_rounded, color: AppTheme.dangerRed, size: 24),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.predicted_category.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.textHighContrast,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Report ID: ${issue.id}',
                      style: const TextStyle(
                        color: AppTheme.accentTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, color: AppTheme.textMediumContrast, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            issue.address ?? 'Coordinates Captured',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 13, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Priority and upvotes (Wrapped to prevent overflow)
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Score: ${issue.priorityScore} (${issue.priorityLabel.toUpperCase()})',
                          style: const TextStyle(
                            color: AppTheme.dangerRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (issue.upvoteCount != null && issue.upvoteCount! > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.warningOrange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '🔥 ${issue.upvoteCount} Reports',
                              style: const TextStyle(
                                color: AppTheme.warningOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    issue.status,
                    style: const TextStyle(color: AppTheme.warningOrange, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (issue.status == 'Assigned' || issue.status == 'In-Progress')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            issue.assignedTeams?.isNotEmpty == true 
                              ? issue.assignedTeams![0]['name']
                              : 'Assigned',
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.accentTeal, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          if (issue.assignedTeams?.isNotEmpty == true && issue.assignedTeams![0]['members'] != null)
                            const SizedBox(height: 4),
                          if (issue.assignedTeams?.isNotEmpty == true && issue.assignedTeams![0]['members'] != null)
                            Text(
                              (issue.assignedTeams![0]['members'] as List).join(', '),
                              textAlign: TextAlign.right,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 11),
                            ),
                        ],
                      ),
                    )
                  else if (issue.assignedUsers != null && issue.assignedUsers!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'DETAILED CREW',
                            style: TextStyle(color: AppTheme.accentTeal, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            issue.assignedUsers!.map((u) => u['username'].split('_')[0]).join(', ').toUpperCase(),
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            final msg = await _api.autoAssignComplaint(issue.id);
                            _loadData();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(msg, style: const TextStyle(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold)),
                                  backgroundColor: AppTheme.primaryBlue,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Auto-assign failed.'), backgroundColor: AppTheme.dangerRed),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.dangerRed.withOpacity(0.15),
                          foregroundColor: AppTheme.dangerRed,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('AUTO DISPATCH'),
                      ),
                    ),
                  if (issue.status == 'Assigned' || issue.status == 'In-Progress')
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        height: 32,
                        child: TextButton(
                          onPressed: () => _showManageCrewDialog(issue),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            backgroundColor: AppTheme.primaryBlue.withOpacity(0.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('MANAGE TEAM', style: TextStyle(fontSize: 11, letterSpacing: 0.5)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopCategoriesPane() {
    final tops = _stats!['top_categories'] as List<dynamic>? ?? [];
    if (tops.isEmpty) return const SizedBox.shrink();
    
    final maxCount = tops.fold<int>(0, (max, item) => (item['count'] as int) > max ? (item['count'] as int) : max);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: tops.map((cat) {
            final count = cat['count'] as int;
            final pct = maxCount > 0 ? count / maxCount : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(cat['predicted_category'], style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 15, fontWeight: FontWeight.w500)),
                      Text('$count', style: const TextStyle(color: AppTheme.accentTeal, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppTheme.darkBackground,
                    color: AppTheme.accentTeal,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            );
          }).toList(),
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
            title: Text('Manage Crew - Issue #${issue.id}', style: Theme.of(context).textTheme.titleLarge),
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
                          const Text('No individual members assigned yet.', style: TextStyle(color: AppTheme.textMediumContrast, fontSize: 14))
                        else
                          ...issue.assignedUsers!.map((u) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(radius: 16, backgroundColor: AppTheme.primaryBlue, child: Text(u['username'][0].toUpperCase(), style: const TextStyle(fontSize: 14, color: Colors.white))),
                            title: Row(
                              children: [
                                Text(u['username'], style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 15)),
                                if (u['is_supervisor'] == true || u['is_supervisor'] == 1 || u['is_supervisor'].toString() == 'true')
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(Icons.star_rounded, color: Colors.amberAccent, size: 18),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppTheme.dangerRed, size: 24),
                              onPressed: () async {
                                await _api.manageCrewAssignment(complaintId: issue.id, action: 'remove', userId: u['id']);
                                Navigator.pop(ctx);
                                _loadData();
                              },
                            ),
                          )),
                        const Divider(height: 32),
                        Text('ADD EXTRA PERSONNEL', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textMediumContrast)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 200,
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
                                leading: const Icon(Icons.person_add_outlined, color: AppTheme.accentTeal, size: 24),
                                title: Row(
                                  children: [
                                    Text(crew['username'], style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 15)),
                                    if (crew['is_supervisor'] == true || crew['is_supervisor'] == 1 || crew['is_supervisor'].toString() == 'true')
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: Icon(Icons.star_rounded, color: Colors.amberAccent, size: 18),
                                      ),
                                  ],
                                ),
                                subtitle: Text(crew['department'] ?? '', style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 13)),
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
