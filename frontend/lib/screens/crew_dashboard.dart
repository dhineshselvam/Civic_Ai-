import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CrewDashboardScreen extends StatefulWidget {
  const CrewDashboardScreen({super.key});

  @override
  State<CrewDashboardScreen> createState() => _CrewDashboardScreenState();
}

class _CrewDashboardScreenState extends State<CrewDashboardScreen> {
  final _api = ApiService();
  late Future<List<Complaint>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _tasksFuture = _api.getCrewTasks();
  }

  void _refresh() {
    setState(() {
      _tasksFuture = _api.getCrewTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('FIELD CREW OPS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
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
        child: FutureBuilder<List<Complaint>>(
          future: _tasksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.teal));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
            }
            final tasks = snapshot.data ?? [];
            if (tasks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
                    const SizedBox(height: 16),
                    Text('No assigned tasks', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                  ],
                ),
              );
            }

            return SafeArea(
              child: ListView.builder(
                itemCount: tasks.length,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemBuilder: (context, index) {
                  final t = tasks[index];
                  return _PremiumTaskCard(task: t, onUpdate: _refresh);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PremiumTaskCard extends StatelessWidget {
  const _PremiumTaskCard({required this.task, required this.onUpdate});
  final Complaint task;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final statusColor = task.status == 'Resolved' ? Colors.tealAccent : Colors.orangeAccent;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 6, color: statusColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                task.predicted_category.toUpperCase(),
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
                              ),
                              Row(
                                children: [
                                  if (task.priorityScore >= 60)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withOpacity(0.5))),
                                      child: const Text('URGENT', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      task.status,
                                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              // Image Preview
                              if (task.imageUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    task.imageUrl!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  task.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: Colors.white38, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  task.address ?? 'No address provided',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (task.status != 'Resolved')
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCrewButton(
                                    'UPDATE STATUS', 
                                    Icons.edit_note_rounded, 
                                    Colors.indigoAccent,
                                    () => _showUpdateStatusDialog(context),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCrewButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.4)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  void _showUpdateStatusDialog(BuildContext context) {
    final api = ApiService();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.indigo.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('UPDATE TASK STATUS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 24),
            _statusTile(context, api, 'In-Progress', Icons.directions_run_rounded, Colors.orangeAccent),
            const SizedBox(height: 12),
            _statusTile(context, api, 'Resolved', Icons.check_circle_rounded, Colors.tealAccent),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _statusTile(BuildContext context, ApiService api, String status, IconData icon, Color color) {
    return ListTile(
      onTap: () async {
        await api.updateComplaintStatus(task.id, status);
        if (context.mounted) {
          Navigator.pop(context);
          onUpdate();
        }
      },
      leading: Icon(icon, color: color),
      title: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      tileColor: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.2))),
    );
  }
}
