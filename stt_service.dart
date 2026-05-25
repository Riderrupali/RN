import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  static final SttService instance = SttService._internal();
  final SpeechToText _stt = SpeechToText();

  bool isAvailable = false;
  bool isListening = false;

  SttService._internal();

  Future<bool> init() async {
    isAvailable = await _stt.initialize(
      onError: (error) => isListening = false,
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          isListening = false;
        }
      },
    );
    return isAvailable;
  }

  Future<void> startListening({
    required Function(String text) onResult,
    String localeId = 'en-US',
  }) async {
    if (!isAvailable) return;
    isListening = true;
    await _stt.listen(
      onResult: (result) {
        if (result.finalResult) {
          isListening = false;
          onResult(result.recognizedWords);
        }
      },
      localeId: localeId,
      listenMode: ListenMode.dictation,
      cancelOnError: false,
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
    isListening = false;
  }

  String localeFor(String lang) {
    switch (lang) {
      case 'hindi':
        return 'hi-IN';
      case 'marathi':
        return 'mr-IN';
      default:
        return 'en-US';
    }
  }
}
