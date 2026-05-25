import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ai_service.dart';
import 'tts_service.dart';
import 'database_service.dart';
import '../models/knowledge_model.dart';

class ScreenMonitorService {
  static final ScreenMonitorService instance = ScreenMonitorService._internal();
  ScreenMonitorService._internal();

  static const _channel = MethodChannel('com.codemagic.app/screen');

  bool isMonitoring = false;
  String _lastScreenText = '';
  Timer? _monitorTimer;
  DateTime? _lastSpokenAt;

  final TtsService _tts = TtsService.instance;
  final AiService _ai = AiService.instance;

  // Called every time a new screenshot/OCR result comes in
  Future<void> startMonitoring() async {
    final granted = await Permission.systemAlertWindow.request();
    if (!granted.isGranted) return;

    isMonitoring = true;
    _monitorTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _checkScreen();
    });
  }

  void stopMonitoring() {
    isMonitoring = false;
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  // Process OCR text pasted/shared by user (manual screen read)
  Future<String> analyzeScreenText(String screenText, String language) async {
    if (screenText.trim().isEmpty) return '';

    // Extract keywords from screen text
    final keywords = _extractKeywords(screenText);
    if (keywords.isEmpty) return '';

    // Search knowledge base for matching info
    List<KnowledgeItem> allMatches = [];
    for (final keyword in keywords.take(5)) {
      final results = await DatabaseService.instance.searchKnowledge(keyword);
      allMatches.addAll(results);
    }

    if (allMatches.isEmpty) {
      return _noMatchResponse(screenText, language);
    }

    // Remove duplicates
    final seen = <int>{};
    final unique = allMatches.where((i) => seen.add(i.id ?? 0)).toList();

    return _buildScreenResponse(unique.take(3).toList(), screenText, language);
  }

  // Auto-check screen (called from timer)
  Future<void> _checkScreen() async {
    if (!isMonitoring || _tts.isMuted) return;

    // Cooldown: don't speak more than once every 8 seconds
    if (_lastSpokenAt != null &&
        DateTime.now().difference(_lastSpokenAt!).inSeconds < 8) return;

    try {
      // Get screen text via platform channel (requires MediaProjection on Android)
      final String? screenText =
          await _channel.invokeMethod<String>('getScreenText');
      if (screenText == null || screenText.trim().isEmpty) return;
      if (screenText == _lastScreenText) return; // No change

      _lastScreenText = screenText;
      final lang = _tts.language == AppLanguage.hindi
          ? 'hindi'
          : _tts.language == AppLanguage.marathi
              ? 'marathi'
              : 'english';

      final response = await analyzeScreenText(screenText, lang);
      if (response.isNotEmpty) {
        _lastSpokenAt = DateTime.now();
        await _tts.speak(response);
      }
    } catch (_) {
      // Platform channel not available in dev — handled gracefully
    }
  }

  List<String> _extractKeywords(String text) {
    // Remove common words, extract meaningful keywords
    final stopWords = {
      'the', 'a', 'an', 'is', 'are', 'was', 'to', 'of', 'and', 'or',
      'in', 'on', 'at', 'by', 'for', 'with', 'this', 'that', 'it',
      'he', 'she', 'we', 'you', 'i', 'me', 'my', 'your', 'his', 'her',
      'का', 'के', 'की', 'में', 'से', 'को', 'है', 'हैं', 'था', 'थी',
      'चा', 'ची', 'चे', 'मध्ये', 'आहे', 'आहेत',
    };

    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3 && !stopWords.contains(w))
        .toSet()
        .toList();

    return words;
  }

  String _buildScreenResponse(
      List<KnowledgeItem> items, String screenText, String language) {
    final buffer = StringBuffer();

    switch (language) {
      case 'marathi':
        buffer.write('Screen वर पाहिलेल्या माहितीवरून: ');
        for (final item in items) {
          if (item.appName != null && item.appName!.isNotEmpty) {
            buffer.write('${item.appName} बद्दल — ');
          }
          buffer.write('${item.content}. ');
        }
        break;
      case 'hindi':
        buffer.write('स्क्रीन देखकर: ');
        for (final item in items) {
          if (item.appName != null && item.appName!.isNotEmpty) {
            buffer.write('${item.appName} के बारे में — ');
          }
          buffer.write('${item.content}. ');
        }
        break;
      default:
        buffer.write('Based on your screen: ');
        for (final item in items) {
          if (item.appName != null && item.appName!.isNotEmpty) {
            buffer.write('About ${item.appName} — ');
          }
          buffer.write('${item.content}. ');
        }
    }
    return buffer.toString();
  }

  String _noMatchResponse(String screenText, String language) {
    // Extract first meaningful phrase from screen
    final lines = screenText
        .split('\n')
        .where((l) => l.trim().length > 4)
        .take(2)
        .join(', ');

    switch (language) {
      case 'marathi':
        return 'Screen वर "$lines" दिसतंय. याबद्दल माझ्याकडे माहिती नाही. तुम्ही मला शिकवाल का?';
      case 'hindi':
        return 'Screen पर "$lines" दिख रहा है। मुझे इसके बारे में जानकारी नहीं। क्या आप बताएंगे?';
      default:
        return 'I see "$lines" on screen. I don\'t have info about this yet. Can you teach me?';
    }
  }
}
