import 'dart:async';
import 'dart:math';
import 'tts_service.dart';
import 'database_service.dart';
import 'market_analysis_service.dart';
import '../models/knowledge_model.dart';

class ContinuousTalkService {
  static final ContinuousTalkService instance =
      ContinuousTalkService._internal();
  ContinuousTalkService._internal();

  final TtsService _tts = TtsService.instance;
  final MarketAnalysisService _market = MarketAnalysisService.instance;

  bool isActive = false;
  Timer? _talkTimer;
  Timer? _idleTimer;
  String _lastScreenText = '';
  DateTime? _lastSpokenAt;
  int _silenceSeconds = 0;

  // ज्या screen text वर आधीच बोललो ते track करायला
  final Set<String> _spokenTexts = {};

  void start({String language = 'marathi'}) {
    isActive = true;
    _silenceSeconds = 0;

    // Every 3 seconds — screen text check
    _talkTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      _silenceSeconds += 3;
      if (!isActive || _tts.isMuted || _tts.isSpeaking) return;
      // idle chat after 12 seconds of silence
      if (_silenceSeconds >= 12) {
        await _speakIdleChat(language);
        _silenceSeconds = 0;
      }
    });
  }

  void stop() {
    isActive = false;
    _talkTimer?.cancel();
    _idleTimer?.cancel();
    _talkTimer = null;
    _idleTimer = null;
    _spokenTexts.clear();
    _silenceSeconds = 0;
  }

  // Called every time new OCR text comes in from screen
  Future<void> onNewScreenText(String screenText, String language) async {
    if (!isActive || _tts.isMuted) return;
    if (screenText.trim().isEmpty) return;

    // Don't repeat same text
    final key = screenText.trim().substring(
        0, screenText.trim().length.clamp(0, 80));
    if (_spokenTexts.contains(key)) return;

    // Detect if it's market/trading screen
    final isMarket = _market.isMarketScreen(screenText);
    String response = '';

    if (isMarket) {
      response = await _market.analyzeMarketScreen(screenText, language);
    } else {
      response = await _analyzeWithKnowledge(screenText, language);
    }

    if (response.isNotEmpty) {
      _spokenTexts.add(key);
      if (_spokenTexts.length > 30) _spokenTexts.clear(); // memory clear
      _lastSpokenAt = DateTime.now();
      _silenceSeconds = 0;
      await _tts.speak(response);
    }
  }

  // Search knowledge base for matching info
  Future<String> _analyzeWithKnowledge(String screenText, String language) async {
    final words = screenText
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet()
        .take(8)
        .toList();

    List<KnowledgeItem> matches = [];
    for (final word in words) {
      final results = await DatabaseService.instance.searchKnowledge(word);
      matches.addAll(results);
    }

    if (matches.isEmpty) return '';

    final seen = <int>{};
    final unique = matches.where((i) => seen.add(i.id ?? 0)).take(2).toList();

    return _buildResponse(unique, language);
  }

  String _buildResponse(List<KnowledgeItem> items, String language) {
    final buffer = StringBuffer();
    for (final item in items) {
      switch (language) {
        case 'marathi':
          buffer.write('${item.topic} बद्दल — ${item.content}. ');
          break;
        case 'hindi':
          buffer.write('${item.topic} के बारे में — ${item.content}. ');
          break;
        default:
          buffer.write('About ${item.topic}: ${item.content}. ');
      }
    }
    return buffer.toString().trim();
  }

  // Idle chat — when nothing on screen matches
  Future<void> _speakIdleChat(String language) async {
    if (_tts.isSpeaking || _tts.isMuted) return;
    final phrases = _getIdlePhrases(language);
    final rnd = Random();
    final phrase = phrases[rnd.nextInt(phrases.length)];
    await _tts.speak(phrase);
  }

  List<String> _getIdlePhrases(String language) {
    switch (language) {
      case 'marathi':
        return [
          'मी इथेच आहे. काही माहिती हवी असेल तर सांगा.',
          'Screen पाहतोय. काही नवीन दिसलं की सांगेन.',
          'तुम्हाला काही प्रश्न आहे का? विचारा!',
          'मी तयार आहे. बोला किंवा screen दाखवा.',
          'सगळं ठीक आहे. मी लक्ष ठेवतोय.',
          'काही काम असेल तर सांगा, मी मदत करतो.',
          'आत्ता screen मध्ये कोणती माहिती नाही. पण मी इथेच आहे.',
          'हे app छान चालतंय! काही शिकवायचं असेल तर सांगा.',
        ];
      case 'hindi':
        return [
          'मैं यहाँ हूँ। कुछ जानना हो तो पूछें।',
          'Screen देख रहा हूँ। कुछ नया दिखा तो बताऊंगा।',
          'कोई सवाल है? पूछें!',
          'तैयार हूँ। बोलें या screen दिखाएं।',
          'सब ठीक है। ध्यान रख रहा हूँ।',
        ];
      default:
        return [
          "I'm here. Ask me anything!",
          "Watching the screen. I'll speak up if I see something relevant.",
          "All good. I'm ready to help.",
          "Nothing new on screen. Just let me know what you need!",
        ];
    }
  }

  // User ने text दिलं → process करा
  Future<String> processUserText(String text, String language) async {
    if (text.trim().isEmpty) return '';

    // Market/trading text आहे का?
    final isMarket = _market.isMarketScreen(text);
    if (isMarket) {
      return await _market.analyzeMarketScreen(text, language);
    }

    // Knowledge base search
    final results = await DatabaseService.instance.searchKnowledge(text);
    if (results.isNotEmpty) {
      return _buildResponse(results.take(2).toList(), language);
    }

    return _getUnknownResponse(text, language);
  }

  String _getUnknownResponse(String topic, String language) {
    switch (language) {
      case 'marathi':
        return '"$topic" बद्दल माझ्याकडे अजून माहिती नाही. तुम्ही मला chat मध्ये सांगाल का? मी save करतो.';
      case 'hindi':
        return '"$topic" के बारे में अभी जानकारी नहीं है। Chat में बताएं, मैं save कर लूंगा।';
      default:
        return 'I don\'t have info about "$topic" yet. Tell me in chat and I\'ll remember it!';
    }
  }
}
