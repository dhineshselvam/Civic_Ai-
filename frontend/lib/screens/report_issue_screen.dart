import 'dart:convert';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../services/api_service.dart';
import '../widgets/map_picker.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final ApiService _api = ApiService();

  dynamic _image; 
  String? _imageName;
  double? _latitude;
  double? _longitude;
  DateTime _timestamp = DateTime.now();
  bool _loading = false;
  bool _isLocationLoading = false;
  String? _successMessage;
  String? _predictedCategory;
  String? _error;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Permission denied';
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      _onLocationSelected(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Location error: $e');
    } finally {
      if (mounted) setState(() => _isLocationLoading = false);
    }
  }

  Future<void> _getAddress(double lat, double lng) async {
    try {
      setState(() => _addressController.text = 'Fetching address...');
      // Use OpenStreetMap Nominatim — works on all platforms including web
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1',
      );
      final response = await http.get(uri, headers: {'Accept-Language': 'en'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          // Build a clean, readable address sentence
          final parts = <String>[
            if (addr['road'] != null) addr['road'] as String,
            if (addr['neighbourhood'] != null) addr['neighbourhood'] as String,
            if (addr['suburb'] != null) addr['suburb'] as String,
            if (addr['city'] != null) addr['city'] as String
            else if (addr['town'] != null) addr['town'] as String
            else if (addr['village'] != null) addr['village'] as String,
            if (addr['state'] != null) addr['state'] as String,
            if (addr['postcode'] != null) addr['postcode'] as String,
          ];
          final fullAddr = parts.where((p) => p.isNotEmpty).join(', ');
          if (mounted) setState(() => _addressController.text = fullAddr.isNotEmpty ? fullAddr : (data['display_name'] as String? ?? ''));
        } else {
          final display = data['display_name'] as String?;
          if (mounted && display != null) setState(() => _addressController.text = display);
        }
      } else {
        if (mounted) setState(() => _addressController.text = 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}');
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      if (mounted) setState(() => _addressController.text = 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}');
    }
  }

  Future<Uint8List> _compressImage(Uint8List list) async {
    if (kIsWeb) return list; // flutter_image_compress is not supported on web
    try {
      final result = await FlutterImageCompress.compressWithList(
        list,
        minHeight: 1024,
        minWidth: 1024,
        quality: 80,
      );
      return result;
    } catch (e) {
      return list;
    }
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      setState(() {
        _image = file.bytes;
        _imageName = file.name;
        _error = null;
      });
    } else {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.camera_alt, color: Colors.white)),
                title: const Text('Capture with Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.photo_library, color: Colors.white)),
                title: const Text('Pick from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: source);
      if (xFile == null) return;

      final originalBytes = await xFile.readAsBytes();
      final compressedBytes = await _compressImage(originalBytes);

      setState(() {
        _image = compressedBytes;
        _imageName = xFile.name;
        _error = null;
      });
    }
  }

  void _onLocationSelected(double lat, double lng) {
    setState(() {
      _latitude = lat;
      _longitude = lng;
      _error = null;
    });
    _getAddress(lat, lng);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_image == null) {
      setState(() => _error = 'Photo is required');
      return;
    }
    if (_latitude == null) {
      setState(() => _error = 'Location is required');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final response = await _api.submitReport(
        imageBytes: _image,
        imageFilename: _imageName ?? 'image.jpg',
        description: _descriptionController.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
        timestamp: DateTime.now(),
        address: _addressController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _loading = false;
        });
        _showSuccessResult(response);
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _showSuccessResult(ReportSubmitResponse response) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.indigo.shade900.withOpacity(0.8),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.tealAccent.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.tealAccent, size: 80),
                const SizedBox(height: 24),
                const Text('REPORT SUBMITTED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 2)),
                const SizedBox(height: 12),
                Text('AI detected this issue as: ${response.predictedCategory}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: response.priorityScore >= 60 ? Colors.redAccent.withOpacity(0.1) : Colors.tealAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: response.priorityScore >= 60 ? Colors.redAccent.withOpacity(0.3) : Colors.transparent)
                  ),
                  child: Column(
                    children: [
                      Text(
                        'PRIORITY: ${response.priorityLabel.toUpperCase()}',
                        style: TextStyle(color: response.priorityScore >= 60 ? Colors.redAccent : Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text('Severity Score: ${response.priorityScore}/100', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('CONTINUE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearForm() {
    _descriptionController.clear();
    _addressController.clear();
    setState(() {
      _image = null;
      _latitude = null;
      _longitude = null;
      _predictedCategory = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Report Civic Issue', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigo.shade900, Colors.teal.shade700],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 700) {
                return _buildDesktopLayout();
              }
              return _buildMobileLayout();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mobile Map Section (Top)
            _buildSectionHeader('Pinpoint Location', Icons.location_on),
            const SizedBox(height: 12),
            _buildMapWidget(height: 280),
            const SizedBox(height: 32),

            // Mobile Form Section (Bottom)
            _buildFormWidgets(),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Side: Map
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionHeader('Pinpoint Location', Icons.location_on),
                  const SizedBox(height: 12),
                  Expanded(child: _buildMapWidget()),
                ],
              ),
            ),
            const SizedBox(width: 32),
            // Right Side: Report Form
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFormWidgets(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapWidget({double? height}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: height, // null height allows Expanded to fill available space on desktop
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
            ),
            child: MapPicker(
              selectedLat: _latitude,
              selectedLng: _longitude,
              onLocationSelected: _onLocationSelected,
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: FloatingActionButton.small(
            onPressed: _isLocationLoading ? null : _getCurrentLocation,
            backgroundColor: Colors.indigo,
            child: _isLocationLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.my_location, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildFormWidgets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Upload Image
        _buildSectionHeader('Visual Evidence', Icons.camera_enhance),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _loading ? null : _pickImage,
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.memory(_image, width: double.infinity, height: double.infinity, fit: BoxFit.contain),
                  )
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_a_photo_rounded, size: 40, color: Colors.tealAccent),
                      ),
                      const SizedBox(height: 16),
                      const Text('TAP TO CAPTURE EVIDENCE', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ],
                  ),
                // Viewport Markers (Decor)
                Positioned(top: 20, left: 20, child: _viewportMarker(0)),
                Positioned(top: 20, right: 20, child: _viewportMarker(1)),
                Positioned(bottom: 20, left: 20, child: _viewportMarker(2)),
                Positioned(bottom: 20, right: 20, child: _viewportMarker(3)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Description
        _buildSectionHeader('Issue Details', Icons.description),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _descriptionController,
          label: 'Describe what\'s wrong',
          icon: Icons.edit_note,
          hint: 'Describe the situation...',
          maxLines: 4,
          validator: (v) => (v == null || v.isEmpty) ? 'Description required' : null,
        ),
        const SizedBox(height: 16),

        // Address Field
        _buildTextField(
          controller: _addressController,
          label: 'Captured Address (Verify & Edit)',
          icon: Icons.map,
          hint: 'Fetching address...',
          maxLines: 2,
        ),
        const SizedBox(height: 40),

        // Messages
        if (_error != null) _buildMessage(Colors.redAccent, _error!),
        if (_successMessage != null) ...[
          _buildMessage(Colors.tealAccent.shade400, _successMessage!),
          const SizedBox(height: 8),
        ],

        // Submit
        SizedBox(
          height: 64,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              foregroundColor: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('SUBMIT REPORT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.teal.shade200, size: 28),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.teal.shade100),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: Icon(icon, color: Colors.teal.shade200),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildMessage(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }

  Widget _viewportMarker(int corner) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        border: Border(
          top: (corner == 0 || corner == 1) ? const BorderSide(color: Colors.tealAccent, width: 2) : BorderSide.none,
          bottom: (corner == 2 || corner == 3) ? const BorderSide(color: Colors.tealAccent, width: 2) : BorderSide.none,
          left: (corner == 0 || corner == 2) ? const BorderSide(color: Colors.tealAccent, width: 2) : BorderSide.none,
          right: (corner == 1 || corner == 3) ? const BorderSide(color: Colors.tealAccent, width: 2) : BorderSide.none,
        ),
      ),
    );
  }
}
