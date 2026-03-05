import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  final ApiService _api = ApiService();
  late Future<List<Complaint>> _complaintsFuture;

  @override
  void initState() {
    super.initState();
    _complaintsFuture = _api.getComplaints();
  }

  void _refresh() {
    setState(() {
      _complaintsFuture = _api.getComplaints();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('My Reports', style: TextStyle(fontWeight: FontWeight.bold)),
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
          future: _complaintsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.teal));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
            }
            final complaints = snapshot.data ?? [];
            if (complaints.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
                    const SizedBox(height: 16),
                    Text('No reports yet', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                  ],
                ),
              );
            }

            return SafeArea(
              child: ListView.builder(
                itemCount: complaints.length,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemBuilder: (context, index) {
                  final c = complaints[index];
                  return _PremiumComplaintCard(complaint: c, onFeedback: _refresh);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PremiumComplaintCard extends StatelessWidget {
  const _PremiumComplaintCard({required this.complaint, required this.onFeedback});
  final Complaint complaint;
  final VoidCallback onFeedback;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Reported': return Colors.blueAccent;
      case 'Verified': return Colors.cyanAccent;
      case 'Assigned': return Colors.purpleAccent;
      case 'In-Progress': return Colors.orangeAccent;
      case 'Resolved': return Colors.tealAccent;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Reported': return Icons.send_rounded;
      case 'Verified': return Icons.verified_rounded;
      case 'Assigned': return Icons.engineering_rounded;
      case 'In-Progress': return Icons.autorenew_rounded;
      case 'Resolved': return Icons.check_circle_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(complaint.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                  // Status Bar Indicator with Icon
                  Container(
                    width: 40,
                    color: statusColor.withOpacity(0.1),
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              complaint.status.toUpperCase(),
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5),
                            ),
                            const SizedBox(width: 8),
                            Icon(_getStatusIcon(complaint.status), color: statusColor, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
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
                                complaint.predicted_category.toUpperCase(),
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: complaint.priorityScore >= 60 ? Colors.redAccent.withOpacity(0.15) : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: complaint.priorityScore >= 60 ? Colors.redAccent.withOpacity(0.5) : Colors.transparent),
                                ),
                                child: Text(
                                  complaint.priorityLabel.toUpperCase(),
                                  style: TextStyle(
                                    color: complaint.priorityScore >= 60 ? Colors.redAccent : Colors.white70, 
                                    fontSize: 10, 
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDate(complaint.createdAt),
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image Thumbnail with subtle border
                              if (complaint.imageUrl != null)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      complaint.imageUrl!,
                                      width: 65,
                                      height: 65,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 65, height: 65,
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.image_outlined, color: Colors.white24),
                                ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      complaint.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.4),
                                    ),
                                    const SizedBox(height: 12),
                                    // Subtle Address preview
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_rounded, color: Colors.white24, size: 12),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            complaint.address ?? 'Registered Location',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          if (complaint.status == 'Resolved') ...[
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 8),
                            if (complaint.rating == null)
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: () => _showFeedbackDialog(context),
                                  icon: const Icon(Icons.star_border_rounded, color: Colors.amberAccent),
                                  label: const Text('RATE RESOLUTION', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  const Text('THANK YOU: ', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ...List.generate(5, (i) => Icon(
                                    i < complaint.rating! ? Icons.star_rounded : Icons.star_outline_rounded,
                                    size: 16,
                                    color: Colors.amberAccent,
                                  )),
                                ],
                              ),
                          ],
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return "Today";
    if (diff.inDays == 1) return "Yesterday";
    return "${date.day}/${date.month}/${date.year}";
  }

  void _showFeedbackDialog(BuildContext context) {
    int selectedRating = 5;
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.indigo.shade900.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white24),
          ),
          title: const Text('Rate Service', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (context, setDialogState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('How satisfied are you with the work?', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) => IconButton(
                    onPressed: () => setDialogState(() => selectedRating = index + 1),
                    icon: Icon(
                      index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amberAccent,
                      size: 36,
                    ),
                  )),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16)),
                  child: TextField(
                    controller: feedbackController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Additional feedback...',
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    maxLines: 3,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: TextStyle(color: Colors.white.withOpacity(0.6)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                await ApiService().submitFeedback(
                  complaint.id, 
                  selectedRating, 
                  feedbackController.text
                );
                Navigator.pop(context);
                onFeedback();
              }, 
              child: const Text('SUBMIT')
            ),
          ],
        ),
      ),
    );
  }
}
