import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Interactive OSM map that captures tap location and shows a marker.
/// Uses flutter_map with OpenStreetMap tiles (no Google Maps).
class MapPicker extends StatefulWidget {
  const MapPicker({
    super.key,
    this.initialCenter,
    this.initialZoom = 15.0,
    this.onLocationSelected,
    this.selectedLat,
    this.selectedLng,
  });

  final LatLng? initialCenter;
  final double initialZoom;
  final void Function(double latitude, double longitude)? onLocationSelected;
  final double? selectedLat;
  final double? selectedLng;

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  final MapController _mapController = MapController();
  LatLng? _center;
  double? _selectedLat;
  double? _selectedLng;

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter ?? const LatLng(28.6139, 77.2090); // Default: Delhi
    _selectedLat = widget.selectedLat;
    _selectedLng = widget.selectedLng;
  }

  @override
  void didUpdateWidget(MapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedLat != _selectedLat || widget.selectedLng != _selectedLng) {
      setState(() {
        _selectedLat = widget.selectedLat;
        _selectedLng = widget.selectedLng;
      });
    }
  }

  void _onTap(TapPosition position, LatLng point) {
    setState(() {
      _selectedLat = point.latitude;
      _selectedLng = point.longitude;
    });
    widget.onLocationSelected?.call(point.latitude, point.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final zoom = widget.initialZoom;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center!,
                initialZoom: zoom,
                onTap: _onTap,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.civic_reporting',
                ),
                if (_selectedLat != null && _selectedLng != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_selectedLat!, _selectedLng!),
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (_selectedLat != null && _selectedLng != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Selected: ${_selectedLat!.toStringAsFixed(6)}, ${_selectedLng!.toStringAsFixed(6)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
