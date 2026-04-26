import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class SupervisorDashboardScreen extends StatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  State<SupervisorDashboardScreen> createState() => _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  final _api = ApiService();
  bool _isLoading = true;
  List<Complaint> _teamTasks = [];
  List<Map<String, dynamic>> _crewMembers = [];
  final MapController _mapController = MapController();
  
  // V3 Dashboard State
  bool _isMapView = true;
  String _filterStatus = 'All'; // 'All', 'Pending', 'Resolved'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;
  bool _isSupervisor = false; // Security flag

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    // Enable Live Sync: Auto-refresh data every 20 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted) _loadDashboardData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await _api.getCrewTasks();
      final allCrew = await _api.listCrewMembers();
      final profile = await _api.getUserProfile();
      
      _crewMembers = allCrew;
      _teamTasks = tasks;
      _isSupervisor = profile['is_supervisor'] == true;

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading dashboard: $e')));
      }
    }
  }

  List<Complaint> get _filteredTasks {
    return _teamTasks.where((t) {
      bool matchesStatus = true;
      if (_filterStatus == 'Pending') matchesStatus = t.status != 'Resolved';
      if (_filterStatus == 'Resolved') matchesStatus = t.status == 'Resolved';
      
      bool matchesSearch = t.predicted_category.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                          (t.address ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      
      return matchesStatus && matchesSearch;
    }).toList();
  }

  List<Map<String, dynamic>> get _displaySquad {
    // Collect everyone from the supervisor's core team
    final Map<int, Map<String, dynamic>> uniqueCrew = {
      for (var c in _crewMembers) c['id'] as int: c
    };

    // ADD: Anyone who is assigned as an individual specialist to any of my filtered tasks
    for (var task in _filteredTasks) {
      if (task.assignedUsers != null) {
        for (var user in task.assignedUsers!) {
          final int uid = user['id'] as int;
          if (!uniqueCrew.containsKey(uid)) {
            uniqueCrew[uid] = user;
          }
        }
      }
    }

    final list = uniqueCrew.values.toList();
    if (_searchQuery.isEmpty) return list;
    return list.where((c) => 
      c['username'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  int get _pendingTasksCount => _teamTasks.where((t) => t.status != 'Resolved').length;
  int get _resolvedCount => _teamTasks.where((t) => t.status == 'Resolved').length;
  int get _squadCount => _crewMembers.length;

  @override
  Widget build(BuildContext context) {
    LatLng mapCenter = const LatLng(13.0827, 80.2707); // Chennai fallback
    // Safely find the first crew member with a location to center the map
    final crewWithLocation = _crewMembers.where((c) => c['current_latitude'] != null).toList();
    
    if (crewWithLocation.isNotEmpty) {
      mapCenter = LatLng(crewWithLocation[0]['current_latitude'], crewWithLocation[0]['current_longitude']);
    } else if (_teamTasks.isNotEmpty) {
      mapCenter = LatLng(_teamTasks[0].latitude, _teamTasks[0].longitude);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: _isMapView 
          ? const Text('OPS CONTROL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 18))
          : TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search tasks or crew...',
                hintStyle: const TextStyle(color: Colors.white38),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    }, icon: const Icon(Icons.close, color: Colors.white70))
                  : null,
              ),
            ),
        backgroundColor: Colors.indigo.shade900.withOpacity(0.4),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent))),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isMapView = !_isMapView),
            icon: Icon(_isMapView ? Icons.format_list_bulleted_rounded : Icons.map_rounded, color: Colors.white),
          ),
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading 
        ? Container(
            color: Colors.indigo.shade900,
            child: const Center(child: CircularProgressIndicator(color: Colors.orangeAccent)),
          )
        : Stack(
            children: [
              _isMapView 
                ? _buildMapLayout(mapCenter)
                : _buildListLayout(),
                
              // Top Stats Bar (Persistent HUD)
              Positioned(
                top: 85, left: 12, right: 12,
                child: Row(
                  children: [
                    _buildStatHubCard('ALL', _teamTasks.length.toString(), Colors.blueAccent, Icons.analytics_rounded, 'All'),
                    const SizedBox(width: 8),
                    _buildStatHubCard('PENDING', _pendingTasksCount.toString(), Colors.redAccent, Icons.warning_amber_rounded, 'Pending'),
                    const SizedBox(width: 8),
                    _buildStatHubCard('SQUAD', _displaySquad.length.toString(), Colors.orangeAccent, Icons.groups_rounded, 'All'),
                    const SizedBox(width: 8),
                    _buildStatHubCard('RESOLVED', _resolvedCount.toString(), Colors.greenAccent, Icons.check_circle_outline_rounded, 'Resolved'),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildMapLayout(LatLng mapCenter) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: mapCenter,
            initialZoom: 13.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.civicai.app',
            ),
            MarkerLayer(
              markers: [
                ..._filteredTasks.map((t) => Marker(
                  point: LatLng(t.latitude, t.longitude),
                  width: 45,
                  height: 45,
                  child: GestureDetector(
                    onTap: () => _showTaskDetail(t),
                    child: Container(
                      decoration: BoxDecoration(
                        color: (t.status == 'Resolved' ? Colors.teal : Colors.redAccent).withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: t.status == 'Resolved' ? Colors.teal : Colors.redAccent, width: 2),
                      ),
                      child: Icon(Icons.warning_amber_rounded, color: t.status == 'Resolved' ? Colors.tealAccent : Colors.redAccent, size: 24),
                    ),
                  ),
                )),
                ..._displaySquad
                  .where((c) => c['current_latitude'] != null && c['current_longitude'] != null)
                  .map((c) => Marker(
                  point: LatLng(c['current_latitude'], c['current_longitude']),
                  width: 50,
                  height: 60,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blueAccent, width: 2),
                        ),
                        child: const CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.blueAccent,
                          child: Icon(Icons.person, color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                        child: Text(c['username'], style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ))
              ],
            ),
          ],
        ),
        // Task Deck & Bottom Panel
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_filteredTasks.isNotEmpty)
                _buildTaskDeck(),
              const SizedBox(height: 16),
              _buildSquadPanel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListLayout() {
    return Container(
      color: Colors.indigo.shade900,
      padding: const EdgeInsets.only(top: 180),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: _filteredTasks.length,
        itemBuilder: (context, index) {
          final t = _filteredTasks[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.white.withOpacity(0.05),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(t.imageUrl ?? '', width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey, width: 60)),
              ),
              title: Text(t.predicted_category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const SizedBox(height: 4),
                   Text(t.address ?? 'No Address', style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1),
                   const SizedBox(height: 8),
                   Row(
                     children: [
                       _buildBadge(t.priorityLabel, t.priorityLabel == 'Critical' ? Colors.redAccent : Colors.orangeAccent),
                       const SizedBox(width: 8),
                       _buildBadge(t.status, t.status == 'Resolved' ? Colors.tealAccent : Colors.white24),
                     ],
                   ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
              onTap: () => _showTaskDetail(t),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatHubCard(String label, String value, Color color, IconData icon, String status) {
    bool isSelected = _filterStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filterStatus = status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.3) : Colors.indigo.shade900.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? color : Colors.white.withOpacity(0.1), width: isSelected ? 2 : 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isSelected ? 0.4 : 0.2), blurRadius: 10, spreadRadius: 0),
              if (isSelected) BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, spreadRadius: -2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 16),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskDeck() {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _filteredTasks.length,
        itemBuilder: (context, index) {
          final t = _filteredTasks[index];
          return GestureDetector(
            onTap: () => _showTaskDetail(t),
            child: Container(
              width: 290,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade900.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
                      image: DecorationImage(image: NetworkImage(t.imageUrl ?? ''), fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.predicted_category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(t.address ?? 'Unlabeled Location', style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildBadge(t.priorityLabel, t.priorityLabel == 'Critical' ? Colors.redAccent : Colors.orangeAccent),
                            _buildBadge(t.status, t.status == 'Resolved' ? Colors.tealAccent : Colors.white24),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _resolveTask(Complaint t) async {
    // Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.indigo.shade900,
        title: const Text('Confirm Resolution', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to mark this issue as Resolved? This will notify the citizen.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
            child: const Text('YES, RESOLVED', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.updateComplaintStatus(t.id, 'Resolved');
      if (mounted) {
        Navigator.pop(context); // Close detail panel
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue marked as Resolved!'), backgroundColor: Colors.green),
        );
        _loadDashboardData(); // Refresh counts
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showTaskDetail(Complaint t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.indigo.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(t.predicted_category.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1))),
                  _buildBadge(t.priorityLabel, t.priorityLabel == 'Critical' ? Colors.redAccent : Colors.orangeAccent),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(t.imageUrl ?? '', height: 250, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 24),
              // NEW: Response Squad Section
              const Text('RESPONSE SQUAD', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              if ((t.assignedTeams != null && t.assignedTeams!.isNotEmpty) || (t.assignedUsers != null && t.assignedUsers!.isNotEmpty)) ...[
                if (t.assignedTeams != null)
                  ...t.assignedTeams!.map((team) => Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.blue.withOpacity(0.1), Colors.transparent]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.groups_rounded, color: Colors.blueAccent, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(team['name'] ?? 'Unknown Team', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                (team['members'] as List<dynamic>?)?.join(', ') ?? 'No members listed',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                if (t.assignedUsers != null)
                  ...t.assignedUsers!.where((u) {
                    // DEDUPLICATION: Only show individuals if they aren't already listed in an assigned team
                    if (t.assignedTeams == null) return true;
                    final String uname = u['username'] ?? '';
                    for (var team in t.assignedTeams!) {
                      final members = team['members'] as List<dynamic>?;
                      if (members != null && members.contains(uname)) return false;
                    }
                    return true;
                  }).map((u) => Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.tealAccent,
                          child: Icon(Icons.person, color: Colors.black, size: 14),
                        ),
                        const SizedBox(width: 12),
                        Text(u['username'] ?? 'User', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const Spacer(),
                        const Text('Specialist', style: TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  )),
              ] else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.hourglass_empty_rounded, color: Colors.orangeAccent, size: 20),
                      SizedBox(width: 16),
                      Text('Awaiting Crew Dispatch...', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const Text('LOCATION', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Text(t.address ?? 'Exact location pending...', style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 24),
              const Text('DESCRIPTION', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Text(t.description ?? 'No additional description provided.', style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
              const SizedBox(height: 32),
              const Text('STATUS HISTORY', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              _buildTimelineStep('Reported', '2 hours ago', true),
              _buildTimelineStep('Validated', '1 hour ago', true),
              _buildTimelineStep('In Progress', 'Assigned to your team', t.status != 'Pending'),
              _buildTimelineStep('Resolved', 'Awaiting closure', t.status == 'Resolved'),
              const SizedBox(height: 30),
              
              // NEW: Resolve Button (Interactive Closure)
              if (_isSupervisor && t.status != 'Resolved')
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.greenAccent.withOpacity(0.3), blurRadius: 20, spreadRadius: -5),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => _resolveTask(t),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                        SizedBox(width: 12),
                        Text('MARK AS RESOLVED', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      ],
                    ),
                  ),
                )
              else if (t.status == 'Resolved')
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                  child: const Center(
                    child: Text('ISSUE CLOSED / RESOLVED', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12)),
                  ),
                ),

              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.05),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('CLOSE PANEL', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStep(String title, String subtitle, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: done ? Colors.tealAccent : Colors.white24, size: 20),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: done ? Colors.white : Colors.white24, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSquadPanel() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          decoration: BoxDecoration(
            color: Colors.indigo.shade900.withOpacity(0.8),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('YOUR SQUAD TRACKING', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  Text('${_displaySquad.length} PERSONNEL', style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 85,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _displaySquad.length,
                  itemBuilder: (context, index) {
                    final crew = _displaySquad[index];
                    return GestureDetector(
                      onTap: () {
                        if (crew['current_latitude'] != null) {
                          _mapController.move(LatLng(crew['current_latitude'], crew['current_longitude']), 16.0);
                        }
                      },
                      child: Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.02)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.indigo.shade400,
                                  child: Text(crew['username'][0].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 10, height: 10,
                                    decoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle, border: Border.all(color: Colors.indigo.shade900, width: 2)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(crew['username'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text(crew['team_name'] ?? 'Specialist', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
