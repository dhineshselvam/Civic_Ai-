import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../widgets/map_picker.dart';

/// Report issue screen: image, description, map location, submit.
/// Mobile: camera/gallery via image_picker. Web: file picker.
class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final ApiService _api = ApiService();

  dynamic _image; // Uint8List on both web and mobile
  String? _imageName;
  double? _latitude;
  double? _longitude;
  DateTime _timestamp = DateTime.now();
  bool _loading = false;
  String? _successMessage;
  String? _predictedCategory;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.bytes == null) return;
      setState(() {
        _image = file.bytes;
        _imageName = file.name;
        _error = null;
      });
    } else {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: source, imageQuality: 85);
      if (xFile == null) return;
      final bytes = await xFile.readAsBytes();
      setState(() {
        _image = bytes;
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
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _successMessage = null;
      _predictedCategory = null;
    });

    if (!_formKey.currentState!.validate()) return;
    if (_image == null) {
      setState(() => _error = 'Please select an image');
      return;
    }
    if (_latitude == null || _longitude == null) {
      setState(() => _error = 'Please select a location on the map');
      return;
    }

    _timestamp = DateTime.now();
    setState(() => _loading = true);

    try {
      final response = await _api.submitReport(
        imageBytes: _image,
        imageFilename: _imageName ?? 'image.jpg',
        description: _descriptionController.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
        timestamp: _timestamp,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _successMessage = response.message;
        _predictedCategory = response.predictedCategory;
        _clearForm();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Server error: ${e.statusCode}. ${e.body}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _clearForm() {
    _descriptionController.clear();
    setState(() {
      _image = null;
      _imageName = null;
      _latitude = null;
      _longitude = null;
      _timestamp = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Issue'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image picker
              Text(
                'Image (required)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _pickImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(_imageName ?? 'Select image'),
              ),
              if (_image != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _imageName ?? 'Image selected',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 20),

              // Description
              Text(
                'Description (required)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe the issue...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Map location
              Text(
                'Map location (required)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              MapPicker(
                selectedLat: _latitude,
                selectedLng: _longitude,
                onLocationSelected: _onLocationSelected,
              ),
              const SizedBox(height: 20),

              // Timestamp (read-only)
              Text(
                'Timestamp: ${_timestamp.toIso8601String()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),

              if (_successMessage != null) ...[
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _successMessage!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_predictedCategory != null &&
                            _predictedCategory!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Predicted category: $_predictedCategory',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
