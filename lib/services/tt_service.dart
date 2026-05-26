import 'package:flutter_tts/flutter_tts.dart';

enum VoiceType { male, female, child }
enum AppLanguage { english, hindi, marathi }

class TtsService {
  static final TtsService instance = TtsService._internal();
  final FlutterTts _tts = FlutterTts();

  bool isMuted = false;
  bool isSpeaking = false;
  VoiceType voiceType = VoiceType.female;
  AppLanguage language = AppLanguage.english;

  TtsService._internal();

  Future<void> init() async {
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
    await setLanguage(AppLanguage.english);
    _tts.setStartHandler(() => isSpeaking = true);
    _tts.setCompletionHandler(() => isSpeaking = false);
    _tts.setCancelHandler(() => isSpeaking = false);
  }

  Future<void> setLanguage(AppLanguage lang) async {
    language = lang;
    switch (lang) {
      case AppLanguage.english:
        await _tts.setLanguage('en-US');
        break;
      case AppLanguage.hindi:
        await _tts.setLanguage('hi-IN');
        break;
      case AppLanguage.marathi:
        await _tts.setLanguage('mr-IN');
        break;
    }
    await setVoiceType(voiceType);
  }

  Future<void> setVoiceType(VoiceType type) async {
    voiceType = type;
    switch (type) {
      case VoiceType.male:
        await _tts.setPitch(0.85);
        await _tts.setSpeechRate(0.5);
        break;
      case VoiceType.female:
        await _tts.setPitch(1.1);
        await _tts.setSpeechRate(0.5);
        break;
      case VoiceType.child:
        await _tts.setPitch(1.4);
        await _tts.setSpeechRate(0.55);
        break;
    }
  }

  Future<void> speak(String text) async {
    if (isMuted) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    isSpeaking = false;
  }

  void toggleMute() {
    isMuted = !isMuted;
    if (isMuted) stop();
  }

  String get languageGreeting {
    switch (language) {
      case AppLanguage.english:
        return "Hello! I'm Code Magic. How can I help you?";
      case AppLanguage.hindi:
        return "नमस्ते! मैं Code Magic हूँ। आप कैसे हैं?";
      case AppLanguage.marathi:
        return "नमस्कार! मी Code Magic आहे. मी तुम्हाला कशात मदत करू?";
    }
  }
}
