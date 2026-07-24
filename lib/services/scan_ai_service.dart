import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../config/api_config.dart';
import '../models/scan_result_model.dart';

class ScanAiException implements Exception {
  final String message;
  const ScanAiException(this.message);

  @override
  String toString() => message;
}

class ScanAiService {
  final Uri endpoint;
  ScanAiService({Uri? endpoint})
    : endpoint = endpoint ?? ApiConfig.endpoint('/scan');

  Future<ScanResultModel> scan(File image) async {
    try {
      final bytes = await image.readAsBytes().timeout(
        const Duration(seconds: 10),
      );
      if (bytes.isEmpty) {
        throw const ScanAiException('Ảnh đã chọn đang trống.');
      }
      if (bytes.length > 12 * 1024 * 1024) {
        throw const ScanAiException('Ảnh không được vượt quá 12 MB.');
      }

      final request = http.MultipartRequest('POST', endpoint);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: path.basename(image.path),
        ),
      );
      request.headers.addAll(ApiConfig.headers());
      request.headers['Accept'] = 'application/json';

      final streamed = await request.send().timeout(
        const Duration(seconds: 45),
      );
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String? detail;
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          if (error is Map) detail = error['detail']?.toString();
        } on FormatException {
          // Fall back to a status-based message below.
        }
        throw ScanAiException(
          detail ?? 'Máy chủ Scan AI trả về lỗi ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const ScanAiException('Dữ liệu Scan AI không đúng định dạng.');
      }
      return ScanResultModel.fromJson(decoded);
    } on ScanAiException {
      rethrow;
    } on SocketException {
      throw const ScanAiException(
        'Không thể kết nối máy chủ Scan AI. Hãy kiểm tra địa chỉ API.',
      );
    } on TimeoutException {
      throw const ScanAiException(
        'Scan AI phản hồi quá lâu. Hãy thử lại với ảnh rõ và dung lượng nhỏ hơn.',
      );
    } on FormatException {
      throw const ScanAiException('Máy chủ trả về dữ liệu không hợp lệ.');
    } catch (e) {
      throw ScanAiException('Không thể quét ảnh: $e');
    }
  }
}
