import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cross-platform API service for civic reporting.
/// Uses multipart/form-data for report submission.
/// [imageBytes]: Uint8List or List<int> from image_picker (readAsBytes) or file_picker.
class ApiService {
  ApiService({String? baseUrl})
      : _baseUrl = baseUrl ??
            (kIsWeb
                ? 'http://localhost:8000'
                : 'http://10.0.2.2:8000');

  final String _baseUrl;

  String get baseUrl => _baseUrl;

  /// Submit a civic report with image, description, and location.
  /// [imageBytes]: Uint8List or List<int>. [imageFilename]: optional, e.g. for multipart.
  Future<ReportSubmitResponse> submitReport({
    required dynamic imageBytes,
    required String description,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    String imageFilename = 'image.jpg',
  }) async {
    final uri = Uri.parse('$_baseUrl/api/report-issue/');
    final request = http.MultipartRequest('POST', uri);

    final bytes = imageBytes is Uint8List
        ? imageBytes
        : Uint8List.fromList(imageBytes as List<int>);

    request.files.add(http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: imageFilename,
    ));

    request.fields['description'] = description;
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();
    request.fields['timestamp'] = timestamp.toIso8601String();

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ReportSubmitResponse.fromJson(response.body);
    }

    throw ApiException(
      statusCode: response.statusCode,
      body: response.body,
    );
  }
}

/// Response from POST /api/report-issue/
class ReportSubmitResponse {
  ReportSubmitResponse({
    required this.message,
    required this.predictedCategory,
  });

  factory ReportSubmitResponse.fromJson(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return ReportSubmitResponse(
      message: map['message'] as String? ?? 'Success',
      predictedCategory: map['predicted_category'] as String? ?? '',
    );
  }

  final String message;
  final String predictedCategory;
}

class ApiException implements Exception {
  ApiException({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}