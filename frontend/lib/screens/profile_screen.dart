import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _api.getProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: widget.onLogout,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 48),
                   const SizedBox(height: 16),
                   Text('Error loading profile', style: Theme.of(context).textTheme.titleLarge),
                   const SizedBox(height: 8),
                   Text(snapshot.error.toString(), style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                 ],
               ),
             );
          }
          final user = snapshot.data!;
          final trustScore = user['trust_score'] as int;
          
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  // User Header
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentTeal.withOpacity(0.3), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentTeal.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 56,
                      backgroundColor: AppTheme.cardBackground,
                      child: Icon(Icons.person_outline_rounded, size: 60, color: AppTheme.accentTeal),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    user['username'] ?? 'User',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user['email'] ?? '',
                    style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 16),
                  ),
                  const SizedBox(height: 48),

                  // Trust Score Card
                  _buildPremiumTrustCard(trustScore),
                  const SizedBox(height: 32),
                  
                  // Stats Grid
                  Row(
                    children: [
                      Expanded(child: _buildPremiumStatCard('REPORTS', user['reports_count'].toString(), Icons.analytics_outlined, AppTheme.primaryBlue)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildPremiumStatCard('RESOLVED', user['resolved_count'].toString(), Icons.check_circle_outline, AppTheme.accentTeal)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Info Section
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: AppTheme.textMediumContrast.withOpacity(0.1)),
                    ),
                    color: AppTheme.cardBackground,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: AppTheme.accentTeal, size: 24),
                              SizedBox(width: 12),
                              Text('CREDIBILITY SYSTEM', style: TextStyle(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your score represents your contribution to the city. Higher scores are achieved by reporting valid civic issues and lead to priority verification.',
                            style: TextStyle(color: AppTheme.textMediumContrast, fontSize: 15, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // LOGOUT BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.dangerRed.withOpacity(0.1),
                        foregroundColor: AppTheme.dangerRed,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: AppTheme.dangerRed.withOpacity(0.3)),
                        ),
                      ),
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout_rounded, size: 24),
                      label: const Text('SIGN OUT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?', style: TextStyle(fontSize: 16, color: AppTheme.textMediumContrast)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: AppTheme.textHighContrast,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ApiService().logout();
              widget.onLogout();
            },
            child: const Text('SIGN OUT'),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTrustCard(int score) {
    Color scoreColor = score > 70 ? AppTheme.successGreen : (score > 40 ? AppTheme.warningOrange : AppTheme.dangerRed);

    return Card(
      elevation: 4,
      shadowColor: scoreColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: BorderSide(color: scoreColor.withOpacity(0.3)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.cardBackground,
              scoreColor.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
        child: Column(
          children: [
            const Text(
              'CREDIBILITY SCORE', 
              style: TextStyle(color: AppTheme.textMediumContrast, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 32),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 160,
                  width: 160,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 16,
                    backgroundColor: AppTheme.darkBackground,
                    color: scoreColor,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: scoreColor, height: 1.0),
                    ),
                    const Text('%', style: TextStyle(color: AppTheme.textMediumContrast, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
               decoration: BoxDecoration(
                 color: scoreColor.withOpacity(0.15),
                 borderRadius: BorderRadius.circular(24),
               ),
               child: Text(
                 score > 70 ? 'ELITE CITIZEN' : (score > 40 ? 'VERIFIED' : 'RESTRICTED'),
                 style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 14),
               ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textHighContrast),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
