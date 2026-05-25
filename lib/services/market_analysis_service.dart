import 'database_service.dart';

class MarketAnalysisService {
  static final MarketAnalysisService instance =
      MarketAnalysisService._internal();
  MarketAnalysisService._internal();

  // Marathi + Hindi + English trading keywords
  static const _marketKeywords = [
    // English
    'buy', 'sell', 'candle', 'bullish', 'bearish', 'support', 'resistance',
    'rsi', 'macd', 'ema', 'sma', 'volume', 'price', 'chart', 'trade',
    'profit', 'loss', 'stop loss', 'target', 'breakout', 'breakdown',
    'long', 'short', 'entry', 'exit', 'trend', 'uptrend', 'downtrend',
    'nifty', 'banknifty', 'sensex', 'option', 'future', 'index',
    'green candle', 'red candle', 'doji', 'hammer', 'shooting star',
    'stoploss', 'sl', 'tp', 'fibonacci', 'pivot', 'swing',
    // Marathi
    'खरेदी', 'विक्री', 'नफा', 'तोटा', 'किंमत', 'बाजार', 'शेअर',
    'हिरवी कँडल', 'लाल कँडल', 'वर जाईल', 'खाली जाईल',
    'तेजी', 'मंदी', 'थांबा', 'गुंतवणूक', 'शेअर बाजार',
    'वरचा कल', 'खालचा कल', 'फायदा', 'नुकसान', 'लक्ष्य',
    // Hindi
    'खरीद', 'बेचना', 'मुनाफा', 'नुकसान', 'कीमत', 'बाजार',
    'हरी कैंडल', 'लाल कैंडल', 'ऊपर जाएगा', 'नीचे जाएगा',
    'तेज़ी', 'मंदी', 'निवेश', 'शेयर बाजार',
  ];

  bool isMarketScreen(String text) {
    int matchCount = 0;
    for (final kw in _marketKeywords) {
      if (text.toLowerCase().contains(kw.toLowerCase())) matchCount++;
      if (matchCount >= 2) return true;
    }
    return false;
  }

  Future<String> analyzeMarketScreen(String screenText, String language) async {
    final lower = screenText.toLowerCase();

    // Step 1: User's saved trading knowledge (Marathi/Hindi/English)
    final savedAnalysis = await _checkSavedKnowledge(screenText, language);

    // Step 2: Pattern + signal detection
    final patternResult = _detectCandlePattern(lower, language);
    final trendResult   = _detectTrend(lower, language);
    final signalResult  = _detectSignals(lower, language);
    final marathiResult = _detectMarathiSignals(screenText, language);

    final parts = <String>[];
    if (savedAnalysis.isNotEmpty) parts.add(savedAnalysis);
    if (marathiResult.isNotEmpty) parts.add(marathiResult);
    if (patternResult.isNotEmpty) parts.add(patternResult);
    if (trendResult.isNotEmpty)   parts.add(trendResult);
    if (signalResult.isNotEmpty)  parts.add(signalResult);

    if (parts.isEmpty) return _getGenericMarketResponse(language);
    return parts.take(3).join(' ');
  }

  Future<String> _checkSavedKnowledge(String screenText, String language) async {
    // Split on spaces — works for both Latin & Devanagari
    final words = screenText
        .split(RegExp(r'[\s\n\r,।]+'))
        .where((w) => w.trim().length > 2)
        .toSet()
        .take(8)
        .toList();

    for (final word in words) {
      final results = await DatabaseService.instance.searchKnowledge(word.trim());
      if (results.isNotEmpty) {
        final item = results.first;
        switch (language) {
          case 'marathi':
            return '📚 माझ्या knowledge मध्ये: ${item.topic} — ${item.content}';
          case 'hindi':
            return '📚 मेरी knowledge में: ${item.topic} — ${item.content}';
          default:
            return '📚 From my knowledge: ${item.topic} — ${item.content}';
        }
      }
    }
    return '';
  }

  // Marathi-specific signal detection
  String _detectMarathiSignals(String text, String language) {
    final hasUp = text.contains('वर जाईल') || text.contains('तेजी') ||
        text.contains('वरचा कल') || text.contains('हिरवी') ||
        text.contains('ऊपर जाएगा') || text.contains('तेज़ी');
    final hasDown = text.contains('खाली जाईल') || text.contains('मंदी') ||
        text.contains('खालचा कल') || text.contains('लाल') ||
        text.contains('नीचे जाएगा');

    if (hasUp && !hasDown) return _upSignal(language, 'Bullish signal');
    if (hasDown && !hasUp)  return _downSignal(language, 'Bearish signal');
    return '';
  }

  String _detectCandlePattern(String text, String language) {
    const bullish = ['hammer', 'morning star', 'bullish engulfing', 'piercing',
        'green candle', 'bullish', 'doji at support'];
    const bearish = ['shooting star', 'evening star', 'bearish engulfing',
        'dark cloud', 'red candle', 'bearish', 'doji at resistance'];

    final hasBullish = bullish.any((p) => text.contains(p));
    final hasBearish = bearish.any((p) => text.contains(p));

    if (hasBullish && !hasBearish) return _upSignal(language, 'Bullish candle pattern');
    if (hasBearish && !hasBullish) return _downSignal(language, 'Bearish candle pattern');
    return '';
  }

  String _detectTrend(String text, String language) {
    const up   = ['uptrend','higher high','higher low','breakout',
        'above ema','above sma','above resistance','strong bull'];
    const down = ['downtrend','lower high','lower low','breakdown',
        'below ema','below sma','below support','strong bear'];

    final hasUp   = up.any((w) => text.contains(w));
    final hasDown = down.any((w) => text.contains(w));

    if (hasUp && !hasDown)   return _upSignal(language, 'Uptrend detected');
    if (hasDown && !hasUp)   return _downSignal(language, 'Downtrend detected');
    return '';
  }

  String _detectSignals(String text, String language) {
    // RSI
    if (text.contains('rsi')) {
      if (text.contains('oversold') || _extractNumber(text, 'rsi') < 30)
        return _upSignal(language, 'RSI oversold');
      if (text.contains('overbought') || _extractNumber(text, 'rsi') > 70)
        return _downSignal(language, 'RSI overbought');
    }
    // Volume
    if ((text.contains('high volume') || text.contains('volume spike'))) {
      if (text.contains('green')) return _upSignal(language, 'High volume + green candle');
      if (text.contains('red'))   return _downSignal(language, 'High volume + red candle');
    }
    // Support / Resistance
    if (text.contains('support') && text.contains('bounce'))
      return _upSignal(language, 'Bounce from support');
    if (text.contains('resistance') && text.contains('reject'))
      return _downSignal(language, 'Rejected at resistance');
    return '';
  }

  double _extractNumber(String text, String indicator) {
    final regex = RegExp(r'(?:' + indicator + r'[:\s]+)(\d+\.?\d*)', caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match != null) return double.tryParse(match.group(1) ?? '') ?? 50;
    return 50;
  }

  String _upSignal(String language, String reason) {
    switch (language) {
      case 'marathi':
        return '📈 $reason — किंमत वर जाण्याची शक्यता आहे!\n'
            'खरेदीचा विचार करा. स्वतःचा अभ्यास जरूर करा.';
      case 'hindi':
        return '📈 $reason — कीमत ऊपर जाने की संभावना है!\n'
            'खरीदारी सोचें। खुद भी analyze करें।';
      default:
        return '📈 $reason — Price likely to go UP!\n'
            'Consider buying. Always do your own analysis.';
    }
  }

  String _downSignal(String language, String reason) {
    switch (language) {
      case 'marathi':
        return '📉 $reason — किंमत खाली जाण्याची शक्यता आहे!\n'
            'विक्रीचा किंवा थांबण्याचा विचार करा. स्वतःचा अभ्यास जरूर करा.';
      case 'hindi':
        return '📉 $reason — कीमत नीचे जाने की संभावना है!\n'
            'बेचना या रुकना सोचें। खुद भी analyze करें।';
      default:
        return '📉 $reason — Price likely to go DOWN!\n'
            'Consider selling or waiting. Always do your own analysis.';
    }
  }

  String _getGenericMarketResponse(String language) {
    switch (language) {
      case 'marathi':
        return 'Trading screen दिसतंय. Candle pattern, RSI, किंवा trend माहिती द्या — '
            'मी वर/खाली सांगतो. तुमची Marathi मध्ये save केलेली माहिती पण वापरतो.';
      case 'hindi':
        return 'Trading screen दिख रही है। Candle pattern, RSI या trend बताएं — '
            'ऊपर/नीचे बताऊंगा।';
      default:
        return 'Trading screen detected. Give candle pattern, RSI or trend info — '
            'I\'ll tell you up or down direction.';
    }
  }
}
