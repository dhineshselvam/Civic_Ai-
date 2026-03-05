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
                      const SizedBox(height: 4),
                      Text(
                        issue.address ?? 'Location coordinates captured',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Score: ${issue.priorityScore} (${issue.priorityLabel.toUpperCase()})',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (issue.upvoteCount != null && issue.upvoteCount! > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${issue.upvoteCount} reports',
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
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
                    SizedBox(
                      height: 28,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await _api.autoAssignComplaint(issue.id);
                            _loadData();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Auto-assign failed: $e')),
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
}
