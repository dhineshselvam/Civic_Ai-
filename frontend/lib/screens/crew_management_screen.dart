import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CrewManagementScreen extends StatefulWidget {
  const CrewManagementScreen({super.key});

  @override
  State<CrewManagementScreen> createState() => _CrewManagementScreenState();
}

class _CrewManagementScreenState extends State<CrewManagementScreen> {
  final _api = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _crewMembers = [];
  List<Map<String, dynamic>> _teams = [];

  static const _departments = [
    ('ROAD', 'Road Maintenance'),
    ('SANITATION', 'Sanitation & Waste'),
    ('ELECTRICAL', 'Electrical & Lighting'),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final members = await _api.listCrewMembers();
      final teams = await _api.listTeams();
      setState(() {
        _crewMembers = members;
        _teams = teams;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('CREW MANAGEMENT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          )
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
        child: SafeArea(
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MANAGEMENT', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      const SizedBox(height: 20),
                      _buildActionCard(
                        'Onboard New Member',
                        'Register a new specialized field crew member',
                        Icons.person_add_rounded,
                        Colors.tealAccent,
                        _showRegisterDialog,
                      ),
                      const SizedBox(height: 32),
                      const Text('ACTIVE STAFF LIST', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      const SizedBox(height: 16),
                      if (_crewMembers.isEmpty)
                        const Center(child: Text('No crew members registered yet.', style: TextStyle(color: Colors.white38))),
                      ..._crewMembers.map((m) => _buildCrewMemberTile(m)),
                      const SizedBox(height: 32),
                      const Text('DEPARTMENTS', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      const SizedBox(height: 16),
                      ..._departments.map((d) => _buildDepartmentBadge(d.$1, d.$2)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCrewMemberTile(Map<String, dynamic> member) {
    final teamName = member['team_name'] ?? 'No Team Assigned';
    final dept = member['department'] ?? 'General';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade400,
          child: Text(member['username']?[0]?.toUpperCase() ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(member['username'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text('$dept • $teamName', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: TextButton.icon(
          onPressed: () => _showTransferDialog(member),
          icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Colors.tealAccent),
          label: const Text('TRANSFER', style: TextStyle(color: Colors.tealAccent, fontSize: 11)),
          style: TextButton.styleFrom(
            backgroundColor: Colors.tealAccent.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ),
    );
  }

  void _showTransferDialog(Map<String, dynamic> member) {
    final filteredTeams = _teams.where((t) => t['department'] == member['department']).toList();
    int? selectedTeamId = member['team'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: Colors.indigo.shade900,
          title: Text('Transfer ${member['username']}', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select a new team within the same department:', style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 20),
              if (filteredTeams.isEmpty)
                const Text('No other teams found in this department.', style: TextStyle(color: Colors.redAccent))
              else
                DropdownButtonFormField<int>(
                  value: filteredTeams.any((t) => t['id'] == selectedTeamId) ? selectedTeamId : null,
                  dropdownColor: Colors.indigo.shade900,
                  style: const TextStyle(color: Colors.white),
                  items: filteredTeams.map((t) => DropdownMenuItem<int>(
                    value: t['id'],
                    child: Text(t['name']),
                  )).toList(),
                  onChanged: (v) => setDlgState(() => selectedTeamId = v),
                  decoration: const InputDecoration(labelText: 'Target Team', labelStyle: TextStyle(color: Colors.white54)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedTeamId == null ? null : () async {
                try {
                  await _api.updateMemberTeam(selectedTeamId!, member['id'], 'add');
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('UPDATE ASSIGNMENT'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentBadge(String code, String label) {
    final Map<String, Color> colors = {
      'ROAD': Colors.orangeAccent,
      'SANITATION': Colors.greenAccent,
      'ELECTRICAL': Colors.yellowAccent,
    };
    final color = colors[code] ?? Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const Spacer(),
          Text(code, style: TextStyle(color: color.withOpacity(0.5), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: color.withOpacity(0.15), radius: 28, child: Icon(icon, color: color, size: 30)),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRegisterDialog() {
    final userController = TextEditingController();
    final emailController = TextEditingController();
    final passController = TextEditingController();
    String selectedDepartment = _departments[0].$1;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Colors.indigo.shade900.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Colors.white24),
            ),
            title: const Text('Onboard Field Crew', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogField(userController, 'Username', Icons.person),
                  const SizedBox(height: 12),
                  _dialogField(emailController, 'Email Address', Icons.email),
                  const SizedBox(height: 12),
                  _dialogField(passController, 'Temporary Password', Icons.lock, obscure: true),
                  const SizedBox(height: 16),
                  const Text('DEPARTMENT', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedDepartment,
                        isExpanded: true,
                        dropdownColor: Colors.indigo.shade900,
                        iconEnabledColor: Colors.tealAccent,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        items: _departments.map((d) => DropdownMenuItem(
                          value: d.$1,
                          child: Text(d.$2),
                        )).toList(),
                        onChanged: (v) => setDialogState(() => selectedDepartment = v!),
                      ),
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                      ),
                      child: Text(errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                onPressed: () async {
                  setDialogState(() => errorMsg = null);
                  try {
                    await _api.registerCrew(
                      username: userController.text.trim(),
                      email: emailController.text.trim(),
                      password: passController.text.trim(),
                      department: selectedDepartment,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      _loadData(); // Refresh list after registration
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Crew member registered successfully!'), backgroundColor: Colors.teal),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => errorMsg = e.toString());
                  }
                },
                child: const Text('REGISTER'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.tealAccent, size: 20),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
      ),
    );
  }
}
