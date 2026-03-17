import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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
      appBar: AppBar(
        title: const Text('My Reports'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: FutureBuilder<List<Complaint>>(
        future: _complaintsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 48),
                    const SizedBox(height: 16),
                    Text('Error loading reports', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString(), style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('RETRY'),
                    ),
                  ],
                ),
              ),
            );
          }
          final complaints = snapshot.data ?? [];
          if (complaints.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.feed_outlined, size: 80, color: AppTheme.textMediumContrast.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('No reports yet', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.textMediumContrast)),
                  const SizedBox(height: 8),
                  Text('Issues you report will appear here', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }

          return SafeArea(
            child: ListView.builder(
              itemCount: complaints.length,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              itemBuilder: (context, index) {
                final c = complaints[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _PremiumComplaintCard(complaint: c, onFeedback: _refresh),
                );
              },
            ),
          );
        },
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
      case 'Reported': return AppTheme.primaryBlue;
      case 'Verified': return Colors.cyan;
      case 'Assigned': return Colors.purpleAccent;
      case 'In-Progress': return AppTheme.warningOrange;
      case 'Resolved': return AppTheme.successGreen;
      default: return AppTheme.textMediumContrast;
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return "Today";
    if (diff.inDays == 1) return "Yesterday";
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(complaint.status);
    
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      elevation: 4,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Indicator Strip
            Container(
              width: 12,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Category, Date, Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                complaint.predicted_category.toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.textHighContrast, 
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 16, 
                                  letterSpacing: 0.5
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Report ID: ${complaint.id}',
                                style: const TextStyle(
                                  color: AppTheme.accentTeal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDate(complaint.createdAt),
                                style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getStatusIcon(complaint.status), color: statusColor, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                complaint.status.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor, 
                                  fontSize: 12, 
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Body: Image and Description
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (complaint.imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              complaint.imageUrl!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 80, 
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppTheme.darkBackground, 
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.textMediumContrast.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.image_outlined, color: AppTheme.textMediumContrast, size: 32),
                          ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                complaint.description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 15, height: 1.4),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_rounded, color: AppTheme.textMediumContrast, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      complaint.address ?? 'Coordinates Captured',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 13, height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // Footer: Rating
                    if (complaint.status == 'Resolved') ...[
                      const SizedBox(height: 20),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 12),
                      if (complaint.rating == null)
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () => _showFeedbackDialog(context),
                            icon: const Icon(Icons.star_border_rounded, color: AppTheme.warningOrange),
                            label: const Text('RATE RESOLUTION', style: TextStyle(color: AppTheme.warningOrange, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('YOUR RATING: ', style: TextStyle(color: AppTheme.textMediumContrast, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            ...List.generate(5, (i) => Icon(
                              i < complaint.rating! ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 20,
                              color: AppTheme.warningOrange,
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
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    int selectedRating = 5;
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        title: Text('Rate Service', style: Theme.of(context).textTheme.titleLarge),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How satisfied are you with the resolution?', style: TextStyle(color: AppTheme.textMediumContrast, fontSize: 15, height: 1.4)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center, // Center the stars
                children: List.generate(5, (index) => IconButton(
                  onPressed: () => setDialogState(() => selectedRating = index + 1),
                  icon: Icon(
                    index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: AppTheme.warningOrange,
                    size: 40,
                  ),
                )),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: feedbackController,
                style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Additional feedback (optional)',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.textMediumContrast))
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService().submitFeedback(
                  complaint.id, 
                  selectedRating, 
                  feedbackController.text.trim()
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  onFeedback();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thank you for your feedback!'), backgroundColor: AppTheme.successGreen)
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to submit feedback: $e'), backgroundColor: AppTheme.dangerRed)
                  );
                }
              }
            }, 
            child: const Text('SUBMIT')
          ),
        ],
      ),
    );
  }
}
