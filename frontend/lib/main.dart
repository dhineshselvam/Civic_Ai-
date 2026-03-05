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
import 'services/api_service.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
        useMaterial3: true,
        fontFamily: 'Outfit', // High-end vibe
      ),
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

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    final restored = await ApiService().restoreSession();
    if (restored) {
      // Reload the user profile to get the role
      try {
        final profile = await ApiService().getProfile();
        if (mounted) {
          setState(() {
            _isLoggedIn = true;
            _role = (profile['role'] ?? 'CITIZEN').toString().toUpperCase();
            _initialized = true;
          });
          return;
        }
      } catch (_) {
        ApiService().clearToken(); // Token expired/invalid, force re-login
      }
    }
    if (mounted) setState(() => _initialized = true);
  }

  void _onLoginSuccess(Map<String, dynamic> userData) {
    setState(() {
      _isLoggedIn = true;
      _role = (userData['user']['role'] ?? 'CITIZEN').toString().toUpperCase();
      _currentIndex = 0; // Reset tab on login
    });
  }

  void _logout() {
    ApiService().logout();
    setState(() {
      _isLoggedIn = false;
      _role = 'CITIZEN';
      _currentIndex = 0;
    });
  }

  List<Widget> _getScreens() {
    if (_role == 'ADMIN') {
      return [
        const AdminDashboardScreen(),
        AdminReportsScreen(),
        CrewManagementScreen(),
        CityAnalyticsScreen(),
        ProfileScreen(onLogout: _logout),
      ];
    } else if (_role == 'CREW') {
      return [
        const CrewDashboardScreen(),
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
    if (_role == 'ADMIN') {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Status'),
        BottomNavigationBarItem(icon: Icon(Icons.fact_check_rounded), label: 'Reports'),
        BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Crew'),
        BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Analytics'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Admin'),
      ];
    } else if (_role == 'CREW') {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'Tasks'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded), label: 'Alerts'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
      ];
    } else {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.add_location_alt_rounded), label: 'Report'),
        BottomNavigationBarItem(icon: Icon(Icons.history_edu_rounded), label: 'History'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded), label: 'Inbox'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show splash while checking saved session
    if (!_initialized) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.indigo.shade900, Colors.teal.shade800, Colors.black],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_city_rounded, size: 72, color: Colors.white),
                SizedBox(height: 24),
                Text('CIVIC AI', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4)),
                SizedBox(height: 40),
                CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2),
              ],
            ),
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
          color: Colors.black,
          boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 20)],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.tealAccent,
          unselectedItemColor: Colors.white30,
          selectedFontSize: 12,
          unselectedFontSize: 10,
          onTap: (index) => setState(() => _currentIndex = index),
          items: items,
        ),
      ),
    );
  }
}
