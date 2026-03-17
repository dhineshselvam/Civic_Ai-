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
import '../theme/app_theme.dart';

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
        backgroundColor: AppTheme.cardBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textMediumContrast.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppTheme.primaryBlue, child: Icon(Icons.camera_alt, color: AppTheme.textHighContrast)),
                title: Text('Capture with Camera', style: Theme.of(context).textTheme.bodyLarge),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppTheme.accentTeal, child: Icon(Icons.photo_library, color: AppTheme.darkBackground)),
                title: Text('Pick from Gallery', style: Theme.of(context).textTheme.bodyLarge),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 16),
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
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.accentTeal.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 80),
                const SizedBox(height: 24),
                const Text('REPORT SUBMITTED', style: TextStyle(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 1.5, fontFamily: 'Outfit')),
                const SizedBox(height: 12),
                Text('AI detected this issue as: ${response.predictedCategory}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CONTINUE'),
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
      appBar: AppBar(
        title: const Text('Report Civic Issue'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 700) {
              return _buildDesktopLayout();
            }
            return _buildMobileLayout();
          },
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
            _buildSectionHeader('Pinpoint Location', Icons.location_on),
            const SizedBox(height: 16),
            _buildMapWidget(height: 300),
            const SizedBox(height: 40),
            _buildFormWidgets(),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
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
                  const SizedBox(height: 16),
                  Expanded(child: _buildMapWidget()),
                ],
              ),
            ),
            const SizedBox(width: 48),
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
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: height, // null height allows Expanded to fill available space on desktop
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.textMediumContrast.withOpacity(0.2), width: 1.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: MapPicker(
              selectedLat: _latitude,
              selectedLng: _longitude,
              onLocationSelected: _onLocationSelected,
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton.small(
            onPressed: _isLocationLoading ? null : _getCurrentLocation,
            backgroundColor: AppTheme.primaryBlue,
            elevation: 4,
            child: _isLocationLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textHighContrast))
                : const Icon(Icons.my_location, color: AppTheme.textHighContrast),
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
            height: 240,
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.5), width: 1.5),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22), // slightly less than container to fit inside border
                    child: Image.memory(_image, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                  )
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                          ]
                        ),
                        child: const Icon(Icons.add_a_photo_rounded, size: 48, color: AppTheme.accentTeal),
                      ),
                      const SizedBox(height: 24),
                      Text('TAP TO CAPTURE EVIDENCE', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textMediumContrast)),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),

        // Description
        _buildSectionHeader('Issue Details', Icons.description),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          validator: (v) => (v == null || v.isEmpty) ? 'Description required' : null,
          style: const TextStyle(color: AppTheme.textHighContrast, fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Describe what\'s wrong',
            hintText: 'Provide details about the issue...',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 60, left: 16, right: 16), // align to top left
              child: Icon(Icons.edit_note, color: AppTheme.textMediumContrast, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Address Field
        TextFormField(
          controller: _addressController,
          maxLines: 2,
          style: const TextStyle(color: AppTheme.textMediumContrast, fontSize: 15),
          decoration: InputDecoration(
            labelText: 'Captured Address (Verify & Edit)',
            hintText: 'Fetching address...',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 24, left: 16, right: 16),
              child: Icon(Icons.map, color: AppTheme.textMediumContrast, size: 28),
            ),
            // Distinct style for read-only/auto-filled look
            fillColor: AppTheme.darkBackground.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 48),

        // Messages
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.dangerRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.dangerRed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_error!, style: const TextStyle(color: AppTheme.dangerRed, fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
        if (_successMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: AppTheme.successGreen, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_successMessage!, style: const TextStyle(color: AppTheme.successGreen, fontSize: 15, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Submit Button
        SizedBox(
          height: 64,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: AppTheme.darkBackground, strokeWidth: 3))
                : const Text('SUBMIT REPORT', style: TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accentTeal, size: 28),
        const SizedBox(width: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}
