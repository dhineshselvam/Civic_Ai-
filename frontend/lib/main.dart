import 'package:flutter/material.dart';
import 'screens/report_issue_screen.dart';
import 'screens/my_complaints_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/crew_dashboard.dart';
import 'screens/notifications_screen.dart';
import 'screens/admin_reports_screen.dart';
import 'screens/crew_management_screen.dart';
import 'screens/city_analytics_screen.dart';
import 'screens/predictive_analysis_screen.dart';
import 'screens/supervisor_dashboard.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const CivicReportingApp());
}

class CivicReportingApp extends StatelessWidget {
  const CivicReportingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Civic Ai',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isLoggedIn = false;
  bool _initialized = false;
  String _role = 'CITIZEN';
  bool _isSupervisor = false;

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    final restored = await ApiService().restoreSession();
    if (restored) {
      try {
        final profile = await ApiService().getProfile();
        if (mounted) {
          setState(() {
            _isLoggedIn = true;
            _role = (profile['role'] ?? 'CITIZEN').toString().toUpperCase();
            _isSupervisor = profile['is_supervisor'] == true;
            _initialized = true;
          });
          return;
        }
      } catch (_) {
        ApiService().clearToken();
      }
    }
    if (mounted) setState(() => _initialized = true);
  }

  void _onLoginSuccess(Map<String, dynamic> userData) {
    setState(() {
      _isLoggedIn = true;
      _role = (userData['user']['role'] ?? 'CITIZEN').toString().toUpperCase();
      _isSupervisor = userData['user']['is_supervisor'] == true;
      _currentIndex = 0;
    });
  }

  void _logout() {
    ApiService().logout();
    setState(() {
      _isLoggedIn = false;
      _role = 'CITIZEN';
      _isSupervisor = false;
      _currentIndex = 0;
    });
  }

  List<Widget> _getScreens() {
    if (_role == 'ADMIN' || _role == 'PWD' || _role == 'SANITATION' || _role == 'ELECTRICITY') {
      final reportsTitle = _role == 'ADMIN' ? 'ALL REPORTS'
          : _role == 'PWD' ? 'PWD REPORTS'
          : _role == 'SANITATION' ? 'SANITATION REPORTS'
          : 'DEPT REPORTS';
      return [
        const AdminDashboardScreen(),
        AdminReportsScreen(title: reportsTitle),
        CrewManagementScreen(),
        CityAnalyticsScreen(),
        const PredictiveAnalysisScreen(),
        const NotificationInboxScreen(),
        ProfileScreen(onLogout: _logout),
      ];
    } else if (_role == 'CREW') {
      return [
        _isSupervisor ? const SupervisorDashboardScreen() : const CrewDashboardScreen(),
        const NotificationInboxScreen(),
        ProfileScreen(onLogout: _logout),
      ];
    } else {
      return [
        const ReportIssueScreen(),
        const MyComplaintsScreen(),
        const NotificationInboxScreen(),
        ProfileScreen(onLogout: _logout),
      ];
    }
  }

  List<BottomNavigationBarItem> _getNavItems() {
    if (_role == 'ADMIN' || _role == 'PWD' || _role == 'SANITATION' || _role == 'ELECTRICITY') {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded, size: 26), label: 'Status'),
        BottomNavigationBarItem(icon: Icon(Icons.fact_check_rounded, size: 26), label: 'Reports'),
        BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded, size: 26), label: 'Crew'),
        BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded, size: 26), label: 'Analytics'),
        BottomNavigationBarItem(icon: Icon(Icons.auto_graph_rounded, size: 26), label: 'Predict'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded, size: 26), label: 'Alerts'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded, size: 26), label: 'Profile'),
      ];
    } else if (_role == 'CREW') {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded, size: 26), label: 'Tasks'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded, size: 26), label: 'Alerts'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded, size: 26), label: 'Profile'),
      ];
    } else {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.add_location_alt_rounded, size: 26), label: 'Report'),
        BottomNavigationBarItem(icon: Icon(Icons.history_edu_rounded, size: 26), label: 'History'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded, size: 26), label: 'Inbox'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded, size: 26), label: 'Profile'),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show splash while checking saved session
    if (!_initialized) {
      return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_city_rounded, size: 72, color: AppTheme.accentTeal),
              ),
              const SizedBox(height: 32),
              const Text(
                'CIVIC AI',
                style: TextStyle(
                  color: AppTheme.textHighContrast,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(color: AppTheme.accentTeal, strokeWidth: 3),
            ],
          ),
        ),
      );
    }

    if (!_isLoggedIn) {
      return AuthScreen(onLoginSuccess: _onLoginSuccess);
    }

    final screens = _getScreens();
    final items = _getNavItems();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: items,
          // Colors and sizes are now driven by AppTheme's bottomNavigationBarTheme
        ),
      ),
    );
  }
}
