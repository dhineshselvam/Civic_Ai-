import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Interactive OSM map that displays a location pin.
/// When [readOnly] is true (default), the pin cannot be moved by tapping —
/// it is controlled exclusively by GPS or demo-mode coordinates.
class MapPicker extends StatefulWidget {
  const MapPicker({
    super.key,
    this.initialCenter,
    this.initialZoom = 15.0,
    this.onLocationSelected,
    this.selectedLat,
    this.selectedLng,
    this.readOnly = true,
  });

  final LatLng? initialCenter;
  final double initialZoom;
  final void Function(double latitude, double longitude)? onLocationSelected;
  final double? selectedLat;
  final double? selectedLng;
  /// When true the user cannot tap/drag to reposition the pin.
  final bool readOnly;

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
    // Only allow pin placement when NOT in read-only mode
    if (!widget.readOnly) {
      widget.onLocationSelected?.call(point.latitude, point.longitude);
    }
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
        child: Stack(
          children: [
            FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center!,
            initialZoom: widget.initialZoom,
            // Tap is only functional when readOnly = false
            onTap: widget.readOnly ? null : _onTap,
            interactionOptions: const InteractionOptions(
              // Allow pan, pinch zoom, double-tap zoom, and mouse scroll wheel zoom.
              flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom | InteractiveFlag.scrollWheelZoom,
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
            // Zoom controls (top-left)
            Positioned(
              top: 12,
              left: 12,
              child: Column(
                children: [
                  _ZoomButton(
                    icon: Icons.add,
                    onTap: () {
                      final cam = _mapController.camera;
                      _mapController.move(cam.center, (cam.zoom + 1).clamp(1.0, 18.0));
                    },
                  ),
                  const SizedBox(height: 6),
                  _ZoomButton(
                    icon: Icons.remove,
                    onTap: () {
                      final cam = _mapController.camera;
                      _mapController.move(cam.center, (cam.zoom - 1).clamp(1.0, 18.0));
                    },
                  ),
                ],
              ),
            ),
            // Lock-icon overlay: tells the user the pin position is automatic
            if (widget.readOnly)
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, color: Colors.white70, size: 14),
                      SizedBox(width: 6),
                      Text('Location set by GPS', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.55),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
