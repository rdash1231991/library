import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;

  Uri _u(String path) => Uri.parse(baseUrl + path);

  Future<Map<String, dynamic>> createPreset({
    required Uint8List imageBytes,
    required String filename,
  }) async {
    final req = http.MultipartRequest('POST', _u('/preset'));
    req.files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: filename,
      ),
    );
    final resp = await req.send();
    final body = await resp.stream.bytesToString();
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(resp.statusCode, body);
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(resp.statusCode, 'Invalid JSON response');
    }
    return decoded;
  }

  Future<Uint8List> applyPreset({
    required Uint8List imageBytes,
    required String filename,
    required Map<String, dynamic> presetJson,
  }) async {
    final req = http.MultipartRequest('POST', _u('/apply'));
    req.files.add(
      http.MultipartFile.fromBytes('image', imageBytes, filename: filename),
    );
    req.fields['preset_json'] = jsonEncode(presetJson);
    final resp = await req.send();
    final outBytes = await resp.stream.toBytes();
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final body = utf8.decode(outBytes, allowMalformed: true);
      throw ApiException(resp.statusCode, body);
    }
    return outBytes;
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}

