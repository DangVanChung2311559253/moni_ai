import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/ai_chat_model.dart';
import '../models/wallet_model.dart';

class AiChatException implements Exception {
  final String message;
  const AiChatException(this.message);

  @override
  String toString() => message;
}

class AiChatService {
  http.Client? _activeClient;

  void cancelActiveRequest() {
    _activeClient?.close();
    _activeClient = null;
  }

  Future<AiChatResult> send({
    required String message,
    required DateTime currentDate,
    required List<WalletModel> wallets,
    required Map<String, dynamic> financeContext,
  }) async {
    final client = http.Client();
    _activeClient?.close();
    _activeClient = client;
    try {
      final response = await client
          .post(
            ApiConfig.endpoint('/ai/chat'),
            headers: ApiConfig.headers(json: true),
            body: jsonEncode({
              'message': message,
              'current_date': _date(currentDate),
              'wallets': wallets
                  .map(
                    (wallet) => {
                      'id': wallet.id.toString(),
                      'name': wallet.name,
                      'balance': wallet.balance,
                    },
                  )
                  .toList(),
              'finance_context': financeContext,
            }),
          )
          .timeout(const Duration(seconds: 35));
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map ? decoded['detail']?.toString() : null;
        throw AiChatException(
          detail ?? 'Trợ lý AI trả về lỗi ${response.statusCode}.',
        );
      }
      if (decoded is! Map) {
        throw const AiChatException('Trợ lý AI trả dữ liệu không hợp lệ.');
      }
      return AiChatResult.fromJson(Map<String, dynamic>.from(decoded));
    } on AiChatException {
      rethrow;
    } on TimeoutException {
      throw const AiChatException('Gemini phản hồi quá thời gian.');
    } on SocketException {
      throw const AiChatException('Không thể kết nối backend AI.');
    } on http.ClientException {
      throw const AiChatException('Yêu cầu tới Moni AI đã bị hủy.');
    } on FormatException {
      throw const AiChatException('Gemini trả JSON không hợp lệ.');
    } finally {
      if (identical(_activeClient, client)) _activeClient = null;
      client.close();
    }
  }

  String _date(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
