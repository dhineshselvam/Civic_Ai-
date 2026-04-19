import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Predictive Analysis Dashboard – shows zone-based AI forecasts on a map.
class PredictiveAnalysisScreen extends StatefulWidget {
  const PredictiveAnalysisScreen({super.key});

  @override
  State<PredictiveAnalysisScreen> createState() =>
      _PredictiveAnalysisScreenState();
}

class _PredictiveAnalysisScreenState
    extends State<PredictiveAnalysisScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ── month state ──────────────────────────────────────────────────────────
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  int _selectedMonth = DateTime.now().month; // 1-based

  // ── data state ───────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _predictions = [];
  bool _loading = false;
  String? _error;

  // ── zone metadata (removed – coordinates now come from API) ────────────────

  // ── issue icons ───────────────────────────────────────────────────────────
  static const _issueIcons = <String, IconData>{
    'Pothole':     Icons.construction_rounded,
    'Garbage':     Icons.delete_outline_rounded,
    'Streetlight': Icons.lightbulb_outline_rounded,
  };

  @override
  void initState() {
    super.initState();
    _fetchPredictions();
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  Color _riskColor(String risk) {
    switch (risk) {
      case 'High':   return const Color(0xFFEF4444); // Red
      case 'Medium': return const Color(0xFFF97316); // Orange
      default:       return const Color(0xFFEAB308); // Yellow
    }
  }

  Color _riskColorLight(String risk) {
    switch (risk) {
      case 'High':   return const Color(0x33EF4444);
      case 'Medium': return const Color(0x33F97316);
      default:       return const Color(0x33EAB308);
    }
  }

  // ── API ───────────────────────────────────────────────────────────────────
  Future<void> _fetchPredictions() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService().getPredictions(_selectedMonth);
      if (mounted) setState(() { _predictions = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  // ── summary stats ─────────────────────────────────────────────────────────
  Map<String, dynamic> get _summaryStats {
    if (_predictions.isEmpty) {
      return {'topZone': '–', 'topIssue': '–', 'total': 0};
    }
    final sorted = List<Map<String, dynamic>>.from(_predictions)
      ..sort((a, b) =>
          (b['expected_complaints'] as int).compareTo(a['expected_complaints'] as int));
    final topZone = sorted.first['zone'] as String;

    // Most frequent issue
    final freq = <String, int>{};
    for (final p in _predictions) {
      final issue = p['predicted_issue'] as String;
      freq[issue] = (freq[issue] ?? 0) + 1;
    }
    final topIssue = freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final total =
        _predictions.fold<int>(0, (s, p) => s + (p['expected_complaints'] as int));

    return {'topZone': topZone, 'topIssue': topIssue, 'total': total};
  }

  // ── popup ─────────────────────────────────────────────────────────────────
  void _showZonePopup(Map<String, dynamic> zone) {
    final risk    = zone['risk_level'] as String;
    final issue   = zone['predicted_issue'] as String;
    final count   = zone['expected_complaints'] as int;
    final zoneName = zone['zone'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _riskColor(risk).withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(color: _riskColor(risk).withOpacity(0.3), blurRadius: 24),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _riskColorLight(risk),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.location_on_rounded, color: _riskColor(risk), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  zoneName,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _PopupRow(
              icon: _issueIcons[issue] ?? Icons.report_problem_rounded,
              label: 'Primary Target Issue',
              value: issue,
              color: AppTheme.accentTeal,
            ),
            if (zone['issue_probabilities'] != null) ...[
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Issue Probabilities',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              ...((zone['issue_probabilities'] as Map<String, dynamic>).entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Row(
                    children: [
                      Icon(_issueIcons[e.key] ?? Icons.report_problem_rounded, size: 14, color: Colors.white54),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.key, style: const TextStyle(color: Colors.white, fontSize: 13))),
                      Text('${e.value}%', style: const TextStyle(color: AppTheme.accentTeal, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }).toList()),
            ],
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),
            _PopupRow(
              icon: Icons.bar_chart_rounded,
              label: 'Expected Complaints',
              value: '$count',
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(height: 12),
            _PopupRow(
              icon: Icons.warning_amber_rounded,
              label: 'Risk Level',
              value: risk,
              color: _riskColor(risk),
            ),
            const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showHotspotPopup(Map<String, dynamic> zone, Map<String, dynamic> spot) {
    final risk     = zone['risk_level'] as String;
    final issue    = zone['predicted_issue'] as String;
    final zoneName = zone['zone'] as String;
    final probs    = zone['issue_probabilities'] as Map<String, dynamic>?;
    final probText = probs != null ? '${probs[issue]}%' : 'N/A';
    final weight   = (spot['weight'] as num?)?.toInt() ?? 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(color: const Color(0xFFFBBF24).withOpacity(0.3), blurRadius: 24),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.crisis_alert_rounded, color: Color(0xFFFBBF24), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$zoneName Hotspot',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              _PopupRow(
                icon: _issueIcons[issue] ?? Icons.report_problem_rounded,
                label: 'Predicted Issue Category',
                value: issue,
                color: AppTheme.accentTeal,
              ),
              const SizedBox(height: 12),
              _PopupRow(
                icon: Icons.pie_chart_rounded,
                label: 'Issue Probability',
                value: probText,
                color: AppTheme.accentTeal,
              ),
              const SizedBox(height: 12),
              _PopupRow(
                icon: Icons.warning_amber_rounded,
                label: 'Zone Risk Level',
                value: risk,
                color: _riskColor(risk),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),
              _PopupRow(
                icon: Icons.location_on_rounded,
                label: 'Expected Complaint Count',
                value: '$weight',
                color: const Color(0xFFFBBF24),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final stats = _summaryStats;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: AppTheme.darkBackground,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PREDICTIVE ANALYSIS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AI-powered zone risk forecasting',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Month selector ─────────────────────────────────────────
                  _MonthDropdown(
                    months: _months,
                    selected: _selectedMonth,
                    loading: _loading,
                    onChanged: (m) {
                      setState(() => _selectedMonth = m);
                      _fetchPredictions();
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Error banner ───────────────────────────────────────────
                  if (_error != null)
                    _ErrorBanner(
                      message: _error!,
                      onRetry: _fetchPredictions,
                    ),

                  // ── Summary panel ──────────────────────────────────────────
                  if (!_loading && _predictions.isNotEmpty) ...[
                    _SummaryPanel(
                      topZone:  stats['topZone']  as String,
                      topIssue: stats['topIssue'] as String,
                      total:    stats['total']    as int,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Map ────────────────────────────────────────────────────
                  _MapCard(
                    loading: _loading,
                    predictions: _predictions,
                    riskColor: _riskColor,
                    riskColorLight: _riskColorLight,
                    issueIcons: _issueIcons,
                    onMarkerTap: _showZonePopup,
                    onHotspotTap: _showHotspotPopup,
                  ),
                  const SizedBox(height: 16),

                  // ── Legend ─────────────────────────────────────────────────
                  const _RiskLegend(),
                  const SizedBox(height: 20),

                  // ── Predictions List ────────────────────────────────────────
                  if (!_loading && _predictions.isNotEmpty) ...[
                    _PredictionsList(
                      predictions: _predictions,
                      riskColor: _riskColor,
                      riskColorLight: _riskColorLight,
                      issueIcons: _issueIcons,
                      onTap: _showZonePopup,
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _MonthDropdown extends StatelessWidget {
  const _MonthDropdown({
    required this.months,
    required this.selected,
    required this.loading,
    required this.onChanged,
  });

  final List<String> months;
  final int selected;
  final bool loading;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentTeal.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, color: AppTheme.accentTeal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selected,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                onChanged: loading ? null : (v) { if (v != null) onChanged(v); },
                items: List.generate(
                  12,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(months[i]),
                  ),
                ),
              ),
            ),
          ),
          if (loading)
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(color: AppTheme.accentTeal, strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.loading,
    required this.predictions,
    required this.riskColor,
    required this.riskColorLight,
    required this.issueIcons,
    required this.onMarkerTap,
    required this.onHotspotTap,
  });

  final bool loading;
  final List<Map<String, dynamic>> predictions;
  final Color Function(String) riskColor;
  final Color Function(String) riskColorLight;
  final Map<String, IconData> issueIcons;
  final void Function(Map<String, dynamic>) onMarkerTap;
  final void Function(Map<String, dynamic>, Map<String, dynamic>) onHotspotTap;

  // Compute map center from average of all zone coordinates in API response
  LatLng get _mapCenter {
    if (predictions.isEmpty) return const LatLng(11.93, 79.82);
    final lats = predictions.map((p) => (p['latitude'] as num?)?.toDouble() ?? 11.93);
    final lngs = predictions.map((p) => (p['longitude'] as num?)?.toDouble() ?? 79.82);
    return LatLng(
      lats.reduce((a, b) => a + b) / lats.length,
      lngs.reduce((a, b) => a + b) / lngs.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentTeal.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentTeal.withOpacity(0.05),
            blurRadius: 20,
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 11.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.civicai.app',
              ),
              MarkerLayer(
                markers: _buildAllMarkers(),
              ),
            ],
          ),
          if (loading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.accentTeal),
              ),
            ),
          // Map legend label
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_rounded, color: AppTheme.accentTeal, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Puducherry Zones',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          // Hotspot legend
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.crisis_alert_rounded, color: Color(0xFFFBBF24), size: 13),
                  SizedBox(width: 5),
                  Text('Predicted Hotspot', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds both zone summary markers (large) and hotspot markers (small).
  List<Marker> _buildAllMarkers() {
    if (predictions.isEmpty) return [];
    final markers = <Marker>[];

    for (final pred in predictions) {
      final risk      = pred['risk_level'] as String? ?? 'Low';
      final issue     = pred['predicted_issue'] as String? ?? '';
      final lat       = (pred['latitude']  as num?)?.toDouble();
      final lng       = (pred['longitude'] as num?)?.toDouble();
      final hotspots  = pred['hotspots']  as List<dynamic>? ?? [];

      final color    = riskColor(risk);
      final iconData = issueIcons[issue] ?? Icons.report_problem_rounded;

      // ── Large zone summary pin ──────────────────────────────────────────
      if (lat != null && lng != null) {
        markers.add(Marker(
          point: LatLng(lat, lng),
          width: 56,
          height: 64,
          child: GestureDetector(
            onTap: () => onMarkerTap(pred),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.6), blurRadius: 12, spreadRadius: 2),
                    ],
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: Icon(iconData, color: Colors.white, size: 22),
                ),
                CustomPaint(
                  size: const Size(12, 8),
                  painter: _PinTipPainter(color),
                ),
              ],
            ),
          ),
        ));
      }

      // ── Small hotspot pins ──────────────────────────────────────────────
      for (final spot in hotspots) {
        final sLat = (spot['lat'] as num?)?.toDouble();
        final sLng = (spot['lng'] as num?)?.toDouble();
        final weight = (spot['weight'] as num?)?.toInt() ?? 1;
        if (sLat == null || sLng == null) continue;

        markers.add(Marker(
          point: LatLng(sLat, sLng),
          width: 36,
          height: 42,
          child: GestureDetector(
            onTap: () => onHotspotTap(pred, spot as Map<String, dynamic>),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),          // amber hotspot
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFBBF24).withOpacity(0.55),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '$weight',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                CustomPaint(
                  size: const Size(8, 6),
                  painter: _PinTipPainter(const Color(0xFFFBBF24)),
                ),
              ],
            ),
          ),
        ));
      }
    }

    return markers;
  }
}

class _PinTipPainter extends CustomPainter {
  const _PinTipPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.topZone,
    required this.topIssue,
    required this.total,
  });

  final String topZone;
  final String topIssue;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentTeal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.insights_rounded, color: AppTheme.accentTeal, size: 18),
            SizedBox(width: 8),
            Text(
              'Forecast Summary',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              _SummaryItem(
                icon: Icons.my_location_rounded,
                label: 'Top Risk Zone',
                value: topZone,
                color: const Color(0xFFEF4444),
              ),
              const SizedBox(width: 10),
              _SummaryItem(
                icon: Icons.priority_high_rounded,
                label: 'Top Issue',
                value: topIssue,
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 10),
              _SummaryItem(
                icon: Icons.format_list_numbered_rounded,
                label: 'Total Expected',
                value: '$total',
                color: AppTheme.accentTeal,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskLegend extends StatelessWidget {
  const _RiskLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Text(
            'Risk Level:',
            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          _LegendDot(color: const Color(0xFFEF4444), label: 'High'),
          _LegendDot(color: const Color(0xFFF97316), label: 'Medium'),
          _LegendDot(color: const Color(0xFFEAB308), label: 'Low'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _PopupRow extends StatelessWidget {
  const _PopupRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x33EF4444),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Predictions List
// ─────────────────────────────────────────────────────────────────────────────

class _PredictionsList extends StatelessWidget {
  const _PredictionsList({
    required this.predictions,
    required this.riskColor,
    required this.riskColorLight,
    required this.issueIcons,
    required this.onTap,
  });

  final List<Map<String, dynamic>> predictions;
  final Color Function(String) riskColor;
  final Color Function(String) riskColorLight;
  final Map<String, IconData> issueIcons;
  final void Function(Map<String, dynamic>) onTap;

  // Sort order: High → Medium → Low
  static const _riskOrder = {'High': 0, 'Medium': 1, 'Low': 2};

  @override
  Widget build(BuildContext context) {
    final sorted = List<Map<String, dynamic>>.from(predictions)
      ..sort((a, b) {
        final ra = _riskOrder[a['risk_level']] ?? 3;
        final rb = _riskOrder[b['risk_level']] ?? 3;
        if (ra != rb) return ra.compareTo(rb);
        return (b['expected_complaints'] as int)
            .compareTo(a['expected_complaints'] as int);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              width: 3, height: 18,
              decoration: BoxDecoration(
                color: AppTheme.accentTeal,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Zone Predictions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${sorted.length} zones',
                style: const TextStyle(color: AppTheme.accentTeal, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...sorted.map(
          (pred) => _PredictionCard(
            pred: pred,
            riskColor: riskColor,
            riskColorLight: riskColorLight,
            issueIcon: issueIcons[pred['predicted_issue']] ?? Icons.report_problem_rounded,
            onTap: () => onTap(pred),
          ),
        ),
      ],
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({
    required this.pred,
    required this.riskColor,
    required this.riskColorLight,
    required this.issueIcon,
    required this.onTap,
  });

  final Map<String, dynamic> pred;
  final Color Function(String) riskColor;
  final Color Function(String) riskColorLight;
  final IconData issueIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zone    = pred['zone'] as String;
    final issue   = pred['predicted_issue'] as String;
    final count   = pred['expected_complaints'] as int;
    final risk    = pred['risk_level'] as String;
    final address = pred['address'] as String? ?? '';
    final color   = riskColor(risk);
    final colorBg = riskColorLight(risk);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Issue icon circle
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: colorBg,
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Icon(issueIcon, color: color, size: 20),
            ),
            const SizedBox(width: 14),

            // Zone + issue text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(issueIcon, size: 12, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(
                        issue,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 11, color: color.withOpacity(0.7)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color.withOpacity(0.75),
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Complaint count
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  'complaints',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),

            // Risk badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Text(
                risk,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
