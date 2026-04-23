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

  // Department options matching backend
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
                      const SizedBox(height: 16),
                      _buildActionCard(
                        'Create New Team',
                        'Group crew members into a new operational unit',
                        Icons.group_add_rounded,
                        Colors.orangeAccent,
                        _showCreateTeamDialog,
                      ),
                      const SizedBox(height: 16),
                      _buildActionCard(
                        'Auto-Assemble Teams',
                        'Instantly organize unassigned members into optimal teams',
                        Icons.auto_awesome_rounded,
                        Colors.pinkAccent,
                        () async {
                          setState(() => _isLoading = true);
                          try {
                            final msg = await _api.autoAssembleTeams();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.pinkAccent, duration: const Duration(seconds: 4)));
                            }
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                          _loadData();
                        },
                      ),
                      const SizedBox(height: 32),
                      const Text('OPERATIONAL TEAMS', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      const SizedBox(height: 16),
                      _buildTeamDirectory(),
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

  Widget _buildTeamDirectory() {
    if (_teams.isEmpty) {
      return const Center(child: Text('No operational teams assembled.', style: TextStyle(color: Colors.white38)));
    }
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _teams.length,
        itemBuilder: (context, index) {
          final team = _teams[index];
          final members = team['members'] as List<dynamic>? ?? [];
          final dept = team['department'] ?? 'General';
          
          return Container(
            width: 240,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(team['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                    Icon(Icons.shield_rounded, color: dept == 'ROAD' ? Colors.tealAccent : dept == 'SANITATION' ? Colors.orangeAccent : Colors.pinkAccent, size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Text(dept, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                const Text('MEMBERS', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 8),
                if (members.isEmpty)
                  const Text('No members assigned', style: TextStyle(color: Colors.white24, fontSize: 12))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: members.map((m) {
                      final bool isSup = m['is_supervisor'] == true || m['is_supervisor'] == 1 || m['is_supervisor'].toString() == 'true';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSup ? Colors.orangeAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: isSup ? Colors.orangeAccent.withOpacity(0.3) : Colors.white10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSup) const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 10),
                            if (isSup) const SizedBox(width: 4),
                            Text(
                              m['username'], 
                              style: TextStyle(color: isSup ? Colors.orangeAccent : Colors.white70, fontSize: 11, fontWeight: isSup ? FontWeight.bold : FontWeight.normal)
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCrewMemberTile(Map<String, dynamic> member) {
    final teamName = member['team_name'] ?? 'No Team Assigned';
    final dept = member['department'] ?? 'General';
    final bool isSupervisor = member['is_supervisor'] == true;
    
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
          backgroundColor: isSupervisor ? Colors.orangeAccent.shade400 : Colors.indigo.shade400,
          child: Text(member['username']?[0]?.toUpperCase() ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Row(
          children: [
            Text(member['username'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            if (member['is_supervisor'] == true || member['is_supervisor'] == 1 || member['is_supervisor'].toString() == 'true')
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amberAccent, size: 14),
                    SizedBox(width: 4),
                    Text('SUPERVISOR', style: TextStyle(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
          ],
        ),
        subtitle: Text('$dept • $teamName', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(isSupervisor ? Icons.star_rounded : Icons.star_border_rounded, color: isSupervisor ? Colors.orangeAccent : Colors.white38),
              tooltip: isSupervisor ? 'Revoke Supervisor' : 'Make Supervisor',
              onPressed: () async {
                try {
                  await _api.toggleSupervisor(member['id']);
                  _loadData();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
            ),
            TextButton.icon(
              onPressed: () => _showTransferDialog(member),
              icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Colors.tealAccent),
              label: const Text('TRANSFER', style: TextStyle(color: Colors.tealAccent, fontSize: 11)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.tealAccent.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
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
      'WATER': Colors.blueAccent,
      'PARKS': Colors.tealAccent,
      'GENERAL': Colors.purpleAccent,
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
    final phoneController = TextEditingController();
    final passController = TextEditingController();
    final cityController = TextEditingController(text: 'Chennai'); // Default
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
                  _dialogField(phoneController, 'Mobile Number', Icons.phone_android_rounded),
                  const SizedBox(height: 12),
                  _dialogField(cityController, 'City / Operating Zone', Icons.location_city_rounded),
                  const SizedBox(height: 12),
                  _dialogField(passController, 'Temporary Password', Icons.lock, obscure: true),
                  const SizedBox(height: 4),
                  const Text('One‑time password; change after first login.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 12),
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
                      phone: phoneController.text.trim(),
                      password: passController.text.trim(),
                      department: selectedDepartment,
                      city: cityController.text.trim(),
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

  void _showCreateTeamDialog() {
    final nameController = TextEditingController();
    String selectedDepartment = _departments[0].$1;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Colors.indigo.shade900.withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white24)),
            title: const Text('Create New Team', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogField(nameController, 'Team Name', Icons.groups_rounded),
                const SizedBox(height: 16),
                const Text('DEPARTMENT', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedDepartment,
                      isExpanded: true,
                      dropdownColor: Colors.indigo.shade900,
                      iconEnabledColor: Colors.tealAccent,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      items: _departments.map((d) => DropdownMenuItem(value: d.$1, child: Text(d.$2))).toList(),
                      onChanged: (v) => setDialogState(() => selectedDepartment = v!),
                    ),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Text(errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
                onPressed: () async {
                  setDialogState(() => errorMsg = null);
                  try {
                    await _api.createTeam(nameController.text.trim(), selectedDepartment);
                    if (mounted) {
                      Navigator.pop(context);
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Team created successfully!'), backgroundColor: Colors.orange));
                    }
                  } catch (e) {
                    setDialogState(() => errorMsg = e.toString());
                  }
                },
                child: const Text('CREATE TEAM'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
