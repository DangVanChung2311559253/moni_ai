import 'package:speech_to_text/speech_to_text.dart';

class SpeechInputService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _available = false;

  bool get isListening => _speech.isListening;

  Future<bool> start({
    required void Function(String words) onWords,
    required void Function(bool listening) onListeningChanged,
    required void Function(String message) onError,
  }) async {
    if (!_initialized) {
      _available = await _speech.initialize(
        onStatus: (status) {
          onListeningChanged(status == 'listening');
        },
        onError: (error) {
          onListeningChanged(false);
          onError(_friendlyError(error.errorMsg));
        },
      );
      _initialized = true;
    }
    if (!_available) {
      onError(
        'Không thể dùng micro. Hãy cấp quyền ghi âm cho Moni AI trong Cài đặt.',
      );
      return false;
    }

    String? vietnameseLocale;
    try {
      final locales = await _speech.locales();
      for (final locale in locales) {
        final normalized = locale.localeId.toLowerCase().replaceAll('-', '_');
        if (normalized == 'vi_vn' || normalized.startsWith('vi_')) {
          vietnameseLocale = locale.localeId;
          break;
        }
      }
    } catch (_) {
      // The device default locale is a safe fallback.
    }

    await _speech.listen(
      onResult: (result) => onWords(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        localeId: vietnameseLocale,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      ),
    );
    onListeningChanged(_speech.isListening);
    return _speech.isListening;
  }

  Future<void> stop() async {
    await _speech.stop();
  }

  Future<void> cancel() async {
    await _speech.cancel();
  }

  String _friendlyError(String code) {
    if (code.contains('permission')) {
      return 'Bạn chưa cấp quyền micro cho Moni AI.';
    }
    if (code.contains('network')) {
      return 'Nhận dạng giọng nói cần kết nối mạng. Hãy thử lại.';
    }
    if (code.contains('no_match')) {
      return 'Mình chưa nghe rõ. Bạn hãy nói lại chậm hơn.';
    }
    return 'Không thể nhận dạng giọng nói lúc này. Hãy thử lại.';
  }
}
