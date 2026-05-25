import 'database_service.dart';
import 'screen_monitor_service.dart';
import '../models/knowledge_model.dart';

class AiService {
  static final AiService instance = AiService._internal();
  AiService._internal();

  String _unknownTopic = '';

  Future<String> respondToScreenText(String screenText, String language) async {
    return ScreenMonitorService.instance.analyzeScreenText(screenText, language);
  }

  Future<String> getResponse(String userInput, String language) async {
    final input = userInput.trim();
    final inputLower = input.toLowerCase();

    if (_isMuteCommand(inputLower)) return '__MUTE__';
    if (_isUnmuteCommand(inputLower)) return '__UNMUTE__';
    if (_isTeachOnCommand(inputLower)) return '__TEACH_ON__';
    if (_isTeachOffCommand(inputLower)) return '__TEACH_OFF__';
    if (_isSaveCommand(inputLower)) return _getSavePrompt(language);
    if (_isGreeting(inputLower)) return _getGreeting(language);
    if (_isHelpCommand(inputLower)) return _getHelp(language);

    // Search with original text (supports Marathi / Hindi Unicode)
    final results = await DatabaseService.instance.searchKnowledge(input);
    if (results.isNotEmpty) {
      return _buildKnowledgeResponse(results.first, language);
    }

    // Also search with lowercase for English
    if (input != inputLower) {
      final resultsLower = await DatabaseService.instance.searchKnowledge(inputLower);
      if (resultsLower.isNotEmpty) {
        return _buildKnowledgeResponse(resultsLower.first, language);
      }
    }

    // Try individual words (works for Marathi too via LIKE)
    final words = input.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    for (final word in words.take(5)) {
      final wordResults = await DatabaseService.instance.searchKnowledge(word);
      if (wordResults.isNotEmpty) {
        return _buildKnowledgeResponse(wordResults.first, language);
      }
    }

    _unknownTopic = input;
    return _getUnknownResponse(input, language);
  }

  // ---------------------------------------------------------------
  // TEACH MODE: auto-save any message the user types
  // Extracts a meaningful topic from the text automatically
  // ---------------------------------------------------------------
  Future<String> teachAndSave(String userInput, String language) async {
    final text = userInput.trim();
    if (text.isEmpty) {
      return language == 'marathi'
          ? 'काहीतरी लिहा — मी save करतो!'
          : 'Type something — I\'ll save it!';
    }

    final topic = _extractTopic(text);

    final item = KnowledgeItem(
      topic: topic,
      content: text,
      appName: null,
      createdAt: DateTime.now(),
    );
    await DatabaseService.instance.saveKnowledge(item);

    switch (language) {
      case 'marathi':
        return '✅ Save झाली!\n\n'
            '📌 विषय: $topic\n'
            '📝 माहिती: ${text.length > 80 ? '${text.substring(0, 80)}...' : text}\n\n'
            'Trading analysis आणि game strategy मध्ये मी ही माहिती वापरेन! '
            'आणखी माहिती टाका किंवा "शिकवा बंद" म्हणा.';
      case 'hindi':
        return '✅ Save हो गया!\n\n'
            '📌 विषय: $topic\n'
            '📝 जानकारी: ${text.length > 80 ? '${text.substring(0, 80)}...' : text}\n\n'
            'Trading analysis में उपयोग करूंगा! और जानकारी दें।';
      default:
        return '✅ Saved!\n\n'
            '📌 Topic: $topic\n'
            '📝 Info: ${text.length > 80 ? '${text.substring(0, 80)}...' : text}\n\n'
            'I\'ll use this in trading & game analysis! Add more or say "teach off".';
    }
  }

  // Smart topic extractor — works for Marathi/Hindi/English text
  String _extractTopic(String text) {
    // Common Marathi trading keyword → topic mapping
    final tradingKeywords = {
      'बुलिश': 'Bullish Pattern',
      'bullish': 'Bullish Pattern',
      'बेअरिश': 'Bearish Pattern',
      'bearish': 'Bearish Pattern',
      'कँडल': 'Candlestick Pattern',
      'candle': 'Candlestick Pattern',
      'rsi': 'RSI Indicator',
      'macd': 'MACD Indicator',
      'support': 'Support Level',
      'resistance': 'Resistance Level',
      'सपोर्ट': 'Support Level',
      'ट्रेंड': 'Trend Analysis',
      'trend': 'Trend Analysis',
      'volume': 'Volume Analysis',
      'व्हॉल्यूम': 'Volume Analysis',
      'नफा': 'Profit Strategy',
      'profit': 'Profit Strategy',
      'loss': 'Loss Prevention',
      'नुकसान': 'Loss Prevention',
      'stop loss': 'Stop Loss',
      'target': 'Price Target',
      'breakout': 'Breakout Pattern',
      'indicator': 'Indicator',
    };

    final lower = text.toLowerCase();
    for (final entry in tradingKeywords.entries) {
      if (lower.contains(entry.key.toLowerCase())) return entry.value;
    }

    // Game keywords
    final gameKeywords = {
      'bgmi': 'BGMI Strategy',
      'free fire': 'Free Fire Strategy',
      'pubg': 'PUBG Strategy',
      'strategy': 'Game Strategy',
      'रणनीती': 'Game Strategy',
      'weapon': 'Weapon Strategy',
      'लूट': 'Loot Strategy',
      'drop': 'Drop Strategy',
    };
    for (final entry in gameKeywords.entries) {
      if (lower.contains(entry.key.toLowerCase())) return entry.value;
    }

    // Use first meaningful phrase (up to 40 chars) as topic
    final words = text.split(RegExp(r'[\s,।\n]+')).where((w) => w.length > 1);
    final topicWords = words.take(5).join(' ');
    if (topicWords.length > 40) return '${topicWords.substring(0, 40)}...';
    return topicWords.isNotEmpty ? topicWords : text.substring(0, text.length.clamp(0, 40));
  }

  Future<String> saveNewKnowledge(String topic, String content, String? appName) async {
    final item = KnowledgeItem(
      topic: topic,
      content: content,
      appName: appName,
      createdAt: DateTime.now(),
    );
    await DatabaseService.instance.saveKnowledge(item);
    return topic;
  }

  // ---- Command Detection (Marathi + Hindi + English) ----

  bool _isMuteCommand(String i) =>
      i.contains('mute') || i.contains('शांत') || i.contains('बंद कर') ||
      i.contains('chup') || i.contains('band kar') || i.contains('गप्प');

  bool _isUnmuteCommand(String i) =>
      i.contains('unmute') || i.contains('बोल') || i.contains('speak') ||
      i.contains('bol') || i.contains('चालू कर');

  bool _isTeachOnCommand(String i) =>
      i.contains('शिकवा') || i.contains('shikva') || i.contains('teach on') ||
      i.contains('teach mode') || i.contains('शिकव') || i.contains('shikvaycha') ||
      i.contains('mahiti save kar') || i.contains('माहिती save') ||
      i.contains('learn mode') || i.contains('sikha') || i.contains('शिका');

  bool _isTeachOffCommand(String i) =>
      i.contains('teach off') || i.contains('shikva band') || i.contains('शिकवा बंद') ||
      i.contains('normal chat') || i.contains('stop teach') || i.contains('band karo teach');

  bool _isSaveCommand(String i) =>
      i.contains('save') || i.contains('सेव्ह') || i.contains('शिक') ||
      i.contains('remember') || i.contains('learn') || i.contains('लक्षात ठेव') ||
      i.contains('mahiti save') || i.contains('lavun de') ||
      i.contains('याद रख') || i.contains('संग्रहित') || i.contains('जतन कर');

  bool _isGreeting(String i) =>
      i.contains('hello') || i.contains('hi') || i.contains('नमस्कार') ||
      i.contains('namaste') || i.contains('hey') || i.contains('नमस्ते') ||
      i.contains('कसा आहेस') || i.contains('कसे आहात') || i.contains('कसं चाललंय');

  bool _isHelpCommand(String i) =>
      i.contains('help') || i.contains('मदत') || i.contains('काय करू') ||
      i.contains('kay karu') || i.contains('कशी मदत') || i.contains('क्या कर');

  // ---- Responses ----

  String _getGreeting(String language) {
    switch (language) {
      case 'marathi':
        return 'नमस्कार! मी Code Magic आहे. तुमचा AI मित्र! '
            'मला Marathi मध्ये माहिती द्या, मी समजतो आणि लक्षात ठेवतो. सांगा काय मदत हवी?';
      case 'hindi':
        return 'नमस्ते! मैं Code Magic हूँ। आपका AI दोस्त! '
            'Hindi में बताएं, मैं समझ लूंगा। बोलें, क्या काम है?';
      default:
        return 'Hey! I\'m Code Magic, your personal AI friend! '
            'Tell me anything in English, Marathi or Hindi — I understand all!';
    }
  }

  String _getHelp(String language) {
    switch (language) {
      case 'marathi':
        return 'मी तुम्हाला अशा प्रकारे मदत करू शकतो:\n'
            '• माहिती विचारा — मराठीत सांगतो\n'
            '• माहिती save करा — Marathi मध्ये टाइप करा\n'
            '• Trading screen द्या — analysis देतो\n'
            '• "screen वाच" म्हणा — OCR चालू होईल\n'
            '• Game mode — strategy देतो';
      case 'hindi':
        return 'मैं इस प्रकार मदद कर सकता हूँ:\n'
            '• जानकारी पूछें — Hindi में बताऊंगा\n'
            '• जानकारी save करें — Hindi में type करें\n'
            '• Trading screen दें — analysis दूंगा\n'
            '• Game mode — strategy दूंगा';
      default:
        return 'How I can help:\n'
            '• Ask anything — I\'ll answer\n'
            '• Save knowledge — type or speak in any language\n'
            '• Give trading screen — I\'ll analyze\n'
            '• Game mode — get strategies';
    }
  }

  String _getUnknownResponse(String topic, String language) {
    // Trim long topics
    final display = topic.length > 60 ? '${topic.substring(0, 60)}...' : topic;
    switch (language) {
      case 'marathi':
        return '"$display" बद्दल माझ्याकडे अजून माहिती नाही.\n'
            'तुम्ही मला Marathi मध्ये सांगाल का? मी ते लक्षात ठेवेन आणि पुढच्या वेळी सांगेन.';
      case 'hindi':
        return '"$display" के बारे में अभी जानकारी नहीं है।\n'
            'Hindi में बताएंगे? मैं याद रख लूंगा और अगली बार बताऊंगा।';
      default:
        return 'I don\'t know about "$display" yet.\n'
            'Can you tell me? I\'ll save it and remember for next time!';
    }
  }

  String _getSavePrompt(String language) {
    switch (language) {
      case 'marathi':
        return 'नक्की! आता सांगा — विषय काय आहे आणि माहिती काय आहे?\n'
            'उदाहरण: "Bullish candle म्हणजे हिरवी candle, किंमत वर जाते"';
      case 'hindi':
        return 'ज़रूर! अब बताएं — विषय क्या है और जानकारी क्या है?\n'
            'उदाहरण: "Bullish candle मतलब हरी candle, कीमत ऊपर जाती है"';
      default:
        return 'Sure! Tell me the topic and the information.\n'
            'Example: "Bullish candle means green candle, price goes up"';
    }
  }

  String _buildKnowledgeResponse(KnowledgeItem item, String language) {
    if (item.appName != null && item.appName!.isNotEmpty) {
      switch (language) {
        case 'marathi':
          return '${item.appName} बद्दल:\n${item.content}';
        case 'hindi':
          return '${item.appName} के बारे में:\n${item.content}';
        default:
          return 'About ${item.appName}:\n${item.content}';
      }
    }
    return item.content;
  }

  String get lastUnknownTopic => _unknownTopic;
}
