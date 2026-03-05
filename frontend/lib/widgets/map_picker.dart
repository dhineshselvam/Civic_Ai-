import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Enhanced Interactive OSM map for location selection.
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

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter ?? const LatLng(28.6139, 77.2090);
  }

  @override
  void didUpdateWidget(MapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If coordinates are provided from outside (e.g. auto-capture), move map
    if (widget.selectedLat != null && widget.selectedLng != null) {
      if (widget.selectedLat != oldWidget.selectedLat || widget.selectedLng != oldWidget.selectedLng) {
        final newPoint = LatLng(widget.selectedLat!, widget.selectedLng!);
        _mapController.move(newPoint, _mapController.camera.zoom);
      }
    }
  }

  void _onTap(TapPosition position, LatLng point) {
    widget.onLocationSelected?.call(point.latitude, point.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center!,
            initialZoom: widget.initialZoom,
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
            if (widget.selectedLat != null && widget.selectedLng != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.selectedLat!, widget.selectedLng!),
                    width: 60,
                    height: 60,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const Icon(
                                Icons.location_on,
                                color: Colors.indigo,
                                size: 45,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
