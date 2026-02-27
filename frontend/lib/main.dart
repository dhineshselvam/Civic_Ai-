import 'package:flutter/material.dart';
import 'screens/report_issue_screen.dart';

void main() {
  runApp(const CivicReportingApp());
}

class CivicReportingApp extends StatelessWidget {
  const CivicReportingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Civic Reporting',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ReportIssueScreen(),
    );
  }
}
