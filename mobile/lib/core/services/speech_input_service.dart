import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class SpeechInputService {
  final SpeechToText _speech = SpeechToText();

  bool get isListening => _speech.isListening;

  Future<bool> start({
    required void Function(String text) onText,
    required void Function(bool isListening) onListeningChanged,
    required void Function(String message) onError,
    void Function(double soundLevel)? onSoundLevelChanged,
  }) async {
    final available = await _speech.initialize(
      onStatus: (status) => onListeningChanged(status == 'listening'),
      onError: (error) {
        onListeningChanged(false);
        _onError(error, onError);
      },
    );
    if (!available) {
      onListeningChanged(false);
      onError('Mikrofon veya ses tanıma izni verilmedi.');
      return false;
    }

    onListeningChanged(true);
    try {
      await _speech.listen(
        onResult: (result) => _onResult(result, onText),
        onSoundLevelChange: onSoundLevelChanged,
        listenOptions: SpeechListenOptions(
          localeId: 'tr_TR',
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
        ),
      );
      return true;
    } catch (_) {
      onListeningChanged(false);
      onError('Sesli giriş başlatılamadı. Mikrofon iznini kontrol et.');
      return false;
    }
  }

  Future<void> stop() async {
    if (_speech.isListening) await _speech.stop();
  }

  Future<void> dispose() => _speech.stop();

  void _onResult(
    SpeechRecognitionResult result,
    void Function(String text) onText,
  ) {
    final text = result.recognizedWords.trim();
    if (text.isNotEmpty) onText(text);
  }

  void _onError(
    SpeechRecognitionError error,
    void Function(String message) onError,
  ) {
    if (error.permanent) {
      onError('Sesli giriş başlatılamadı. Mikrofon iznini kontrol et.');
    }
  }
}
