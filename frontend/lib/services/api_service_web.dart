import 'dart:typed_data';

import 'package:http/http.dart' as http;

Future<void> attachImage(http.MultipartRequest request, dynamic imageFile) async {
  if (imageFile == null) throw ArgumentError('Image is required');
  final bytes = imageFile is Uint8List
      ? imageFile
      : (imageFile is List<int> ? Uint8List.fromList(imageFile) : null);
  if (bytes == null) {
    throw ArgumentError('Web: image must be Uint8List or List<int>');
  }
  request.files.add(http.MultipartFile.fromBytes(
    'image',
    bytes,
    filename: 'image.jpg',
  ));
}
