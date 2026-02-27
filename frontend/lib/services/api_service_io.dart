import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> attachImage(http.MultipartRequest request, dynamic imageFile) async {
  if (imageFile == null || (imageFile is File && !imageFile.existsSync())) {
    throw ArgumentError('Image file is required and must exist');
  }
  final file = imageFile as File;
  request.files.add(
    await http.MultipartFile.fromPath('image', file.path),
  );
}
