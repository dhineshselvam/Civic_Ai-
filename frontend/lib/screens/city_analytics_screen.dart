import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';

class CityAnalyticsScreen extends StatefulWidget {
  const CityAnalyticsScreen({super.key});

  @override
  State<CityAnalyticsScreen> createState() => _CityAnalyticsScreenState();
}

class _CityAnalyticsScreenState extends State<CityAnalyticsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getAnalytics();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('CITY ANALYTICS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
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
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
              : _error != null
                  ? _buildError()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_off_rounded, size: 60, color: Colors.white24),
        const SizedBox(height: 16),
        Text('Unable to load analytics', style: TextStyle(color: Colors.white.withAlpha(128), fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('RETRY'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ],
    ),
  );

  Widget _buildContent() {
    final d = _data!;
    final categories = (d['category_breakdown'] as List<dynamic>?) ?? [];
    final statusList = (d['status_breakdown'] as List<dynamic>?) ?? [];
    final trend = (d['daily_trend'] as List<dynamic>?) ?? [];
    final crewLoad = (d['crew_workload'] as List<dynamic>?) ?? [];
    final mapData = (d['map_data'] as List<dynamic>?) ?? [];
    final avgDays = d['avg_resolution_days'];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          // ── SUMMARY STATS ──────────────────────────────────────────────────
          Row(
            children: [
              _statCard('Avg Fix', avgDays != null ? '${avgDays}d' : 'N/A', Icons.timer_rounded, Colors.tealAccent),
              const SizedBox(width: 12),
              _statCard('Types', '${categories.length}', Icons.category_rounded, Colors.purpleAccent),
              const SizedBox(width: 12),
              _statCard('Crew', '${crewLoad.length}', Icons.engineering_rounded, Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 28),

          // ── INTERACTIVE ANALYTICS MAP ───────────────────────────────────────
          _sectionHeader('LIVE ISSUES MAP', Icons.map_rounded),
          const SizedBox(height: 12),
          _glassCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 350,
                child: mapData.isEmpty
                    ? const Center(
                        child: Text(
                          'No location data available.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      )
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: _getMapCenter(mapData),
                          initialZoom: 12.0,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.app',
                          ),
                          MarkerLayer(
                            markers: mapData.map<Marker>((issue) {
                              final lat = double.tryParse(issue['latitude']?.toString() ?? '0') ?? 0;
                              final lng = double.tryParse(issue['longitude']?.toString() ?? '0') ?? 0;
                              final status = issue['status'] as String? ?? 'Reported';
                              final color = _statusColor(status);
                              
                              return Marker(
                                point: LatLng(lat, lng),
                                width: 40,
                                height: 40,
                                child: GestureDetector(
                                  onTap: () => _showIssueDetails(issue),
                                  child: Icon(
                                    Icons.location_on,
                                    color: color,
                                    size: 32,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── 7-DAY TREND BAR CHART ──────────────────────────────────────────
          _sectionHeader('7-DAY REPORT TREND', Icons.bar_chart_rounded),
          const SizedBox(height: 12),
          _glassCard(
            child: SizedBox(
              height: 180,
              child: trend.isEmpty
                  ? const Center(child: Text('No trend data', style: TextStyle(color: Colors.white38)))
                  : Padding(
                      padding: const EdgeInsets.all(8),
                      child: _BarChart(data: trend),
                    ),
            ),
          ),
          const SizedBox(height: 28),

          // ── CATEGORY BREAKDOWN ─────────────────────────────────────────────
          _sectionHeader('ISSUE BREAKDOWN', Icons.pie_chart_rounded),
          const SizedBox(height: 12),
          _glassCard(
            child: Column(
              children: [
                SizedBox(height: 200, child: _PieChart(categories: categories)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12, runSpacing: 8,
                  children: categories.asMap().entries.map((e) {
                    final color = _chartColors[e.key % _chartColors.length];
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('${e.value['predicted_category']}: ${e.value['count']}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ]);
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── STATUS DISTRIBUTION ────────────────────────────────────────────
          _sectionHeader('STATUS DISTRIBUTION', Icons.donut_small_rounded),
          const SizedBox(height: 12),
          ...statusList.map((s) {
            final count = s['count'] as int;
            final total = statusList.fold<int>(0, (a, b) => a + (b['count'] as int));
            final pct = total > 0 ? count / total : 0.0;
            final color = _statusColor(s['status'] as String);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _glassCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Text(s['status'] as String, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                        ]),
                        Text('$count (${(pct * 100).toStringAsFixed(0)}%)', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: pct, backgroundColor: Colors.white.withAlpha(20), color: color, minHeight: 4),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 28),

          // ── CREW WORKLOAD ──────────────────────────────────────────────────
          if (crewLoad.isNotEmpty) ...[
            _sectionHeader('CREW PERFORMANCE', Icons.people_rounded),
            const SizedBox(height: 12),
            ...crewLoad.map((c) {
              final assigned = c['assigned'] as int;
              final resolved = c['resolved'] as int;
              final pct = assigned > 0 ? resolved / assigned : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _glassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(c['username'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.tealAccent.withAlpha(40), borderRadius: BorderRadius.circular(20)),
                            child: Text(c['department'] as String, style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('$resolved / $assigned resolved', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          const Spacer(),
                          Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: pct, backgroundColor: Colors.white.withAlpha(20), color: Colors.tealAccent, minHeight: 4),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  static const _chartColors = [
    Colors.tealAccent, Colors.orangeAccent, Colors.purpleAccent,
    Colors.blueAccent, Colors.pinkAccent, Colors.yellowAccent,
  ];

  LatLng _getMapCenter(List<dynamic> data) {
    if (data.isEmpty) return const LatLng(0, 0);
    double sumLat = 0;
    double sumLng = 0;
    int valid = 0;
    for (var issue in data) {
      final lat = double.tryParse(issue['latitude']?.toString() ?? '');
      final lng = double.tryParse(issue['longitude']?.toString() ?? '');
      if (lat != null && lng != null) {
        sumLat += lat;
        sumLng += lng;
        valid++;
      }
    }
    if (valid == 0) return const LatLng(0, 0);
    return LatLng(sumLat / valid, sumLng / valid);
  }

  void _showIssueDetails(Map<String, dynamic> issue) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final color = _statusColor(issue['status'] as String? ?? '');
        return Container(
          decoration: BoxDecoration(
            color: Colors.indigo.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                      child: Text(issue['status']?.toString().toUpperCase() ?? 'UNKNOWN', 
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                      child: Text(issue['department']?.toString() ?? 'GENERAL', 
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(issue['predicted_category']?.toString() ?? 'No Category', 
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Complaint #${issue['id']} • ${issue['created_at']?.toString().split('T').first ?? 'Date unknown'}', 
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 16),
                const Text('DESCRIPTION', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(issue['description']?.toString() ?? 'No description provided.', 
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Reported': return Colors.blueAccent;
      case 'Verified': return Colors.cyanAccent;
      case 'Assigned': return Colors.purpleAccent;
      case 'In-Progress': return Colors.orangeAccent;
      case 'Resolved': return Colors.tealAccent;
      default: return Colors.grey;
    }
  }

  Widget _sectionHeader(String title, IconData icon) => Row(
    children: [
      Icon(icon, color: Colors.white38, size: 16),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.8)),
    ],
  );

  Widget _statCard(String label, String value, IconData icon, Color color) => Expanded(
    child: _glassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    ),
  );

  Widget _glassCard({required Widget child, EdgeInsets? padding}) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(25)),
        ),
        child: child,
      ),
    ),
  );
}

// ── Custom Bar Chart ─────────────────────────────────────────────────────────
class _BarChart extends StatelessWidget {
  const _BarChart({required this.data});
  final List<dynamic> data;

  @override
  Widget build(BuildContext context) {
    final counts = data.map<int>((d) => d['count'] as int).toList();
    final maxVal = counts.isEmpty ? 1 : counts.reduce(math.max);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.asMap().entries.map((e) {
        final count = e.value['count'] as int;
        final date = (e.value['date'] as String).split(' ').first;
        final frac = maxVal > 0 ? count / maxVal : 0.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (count > 0) Text('$count', style: const TextStyle(color: Colors.white54, fontSize: 9)),
                const SizedBox(height: 2),
                Flexible(
                  child: FractionallySizedBox(
                    heightFactor: frac.clamp(0.05, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.indigo.shade400, Colors.tealAccent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: Colors.white38, fontSize: 9)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Custom Pie Chart ─────────────────────────────────────────────────────────
class _PieChart extends StatelessWidget {
  const _PieChart({required this.categories});
  final List<dynamic> categories;

  static const _colors = [
    Colors.tealAccent, Colors.orangeAccent, Colors.purpleAccent,
    Colors.blueAccent, Colors.pinkAccent, Colors.yellowAccent,
  ];

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(child: Text('No data yet', style: TextStyle(color: Colors.white38)));
    }
    final total = categories.fold<int>(0, (a, b) => a + (b['count'] as int));
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: CustomPaint(
            size: Size(size, size),
            painter: _PieChartPainter(
              values: categories.map<double>((c) => (c['count'] as int).toDouble()).toList(),
              total: total.toDouble(),
              colors: _colors,
            ),
          ),
        );
      },
    );
  }
}

class _PieChartPainter extends CustomPainter {
  _PieChartPainter({required this.values, required this.total, required this.colors});
  final List<double> values;
  final double total;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * 0.85;
    final holeRadius = radius * 0.5;
    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );
      // Gap
      final gapPaint = Paint()
        ..color = Colors.black.withAlpha(100)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        gapPaint,
      );
      startAngle += sweep;
    }

    // Draw hole for donut effect
    canvas.drawCircle(center, holeRadius, Paint()..color = Colors.indigo.shade900);
    // Center text
    final tp = TextPainter(
      text: TextSpan(text: total.toInt().toString(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
