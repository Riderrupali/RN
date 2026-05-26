import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'tts_service.dart';
import 'ocr_service.dart';

class GameService {
  static final GameService instance = GameService._internal();
  GameService._internal();

  Database? _db;
  Timer? _gameTimer;
  String _lastScreenText = '';

  Future<void> _initDb() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'game_knowledge.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE game_knowledge (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_name TEXT NOT NULL,
            move_or_situation TEXT NOT NULL,
            strategy TEXT NOT NULL,
            tags TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // Save a game strategy
  Future<void> saveGameStrategy({
    required String gameName,
    required String moveOrSituation,
    required String strategy,
    String? tags,
  }) async {
    await _initDb();
    await _db!.insert('game_knowledge', {
      'game_name': gameName,
      'move_or_situation': moveOrSituation,
      'strategy': strategy,
      'tags': tags ?? '',
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Get all unique game names
  Future<List<String>> getSavedGames() async {
    await _initDb();
    final maps = await _db!.rawQuery(
        'SELECT DISTINCT game_name FROM game_knowledge ORDER BY game_name');
    return maps.map((m) => m['game_name'] as String).toList();
  }

  // Get all strategies for a game
  Future<List<Map<String, dynamic>>> getGameStrategies(String gameName) async {
    await _initDb();
    return await _db!.query(
      'game_knowledge',
      where: 'game_name = ?',
      whereArgs: [gameName],
      orderBy: 'created_at DESC',
    );
  }

  // Search strategies by keyword
  Future<List<Map<String, dynamic>>> searchStrategies(
      String gameName, String keyword) async {
    await _initDb();
    return await _db!.query(
      'game_knowledge',
      where:
          'game_name = ? AND (move_or_situation LIKE ? OR strategy LIKE ? OR tags LIKE ?)',
      whereArgs: [gameName, '%$keyword%', '%$keyword%', '%$keyword%'],
    );
  }

  Future<void> deleteStrategy(int id) async {
    await _initDb();
    await _db!.delete('game_knowledge', where: 'id = ?', whereArgs: [id]);
  }

  // Core: analyze screen text → return strategy
  Future<String> getStrategyFromScreen(
      String screenText, String gameName, String language) async {
    if (screenText.trim().isEmpty) return '';
    await _initDb();

    // Extract keywords from screen
    final keywords = _extractGameKeywords(screenText);
    List<Map<String, dynamic>> matches = [];

    // Search for matching strategies
    for (final kw in keywords.take(6)) {
      final results = await searchStrategies(gameName, kw);
      matches.addAll(results);
    }

    if (matches.isEmpty) {
      // General game advice
      final allStrategies = await getGameStrategies(gameName);
      if (allStrategies.isEmpty) {
        return _noStrategyResponse(gameName, language);
      }
      // Return most recent strategy as general tip
      final s = allStrategies.first;
      return _buildStrategyResponse(
          [s], screenText, gameName, language, isGeneral: true);
    }

    // Remove duplicates by id
    final seen = <int>{};
    final unique =
        matches.where((m) => seen.add(m['id'] as int)).take(3).toList();

    return _buildStrategyResponse(unique, screenText, gameName, language);
  }

  // Start auto game monitor
  void startGameMonitor({
    required String gameName,
    required String language,
    required Function(String strategy) onStrategy,
  }) {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (TtsService.instance.isMuted) return;
      // Will be fed screen text from platform channel in real use
      // For now responds when user pastes/provides screen text
    });
  }

  void stopGameMonitor() {
    _gameTimer?.cancel();
    _gameTimer = null;
  }

  List<String> _extractGameKeywords(String text) {
    final stopWords = {
      'the', 'a', 'an', 'is', 'are', 'in', 'on', 'at', 'to', 'of', 'and',
      'or', 'it', 'this', 'that', 'with', 'for', 'by', 'you', 'your',
      'का', 'के', 'की', 'में', 'से', 'को', 'है', 'चा', 'ची', 'चे',
    };
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toSet()
        .toList();
  }

  String _buildStrategyResponse(
    List<Map<String, dynamic>> strategies,
    String screenText,
    String gameName,
    String language, {
    bool isGeneral = false,
  }) {
    final buffer = StringBuffer();
    switch (language) {
      case 'marathi':
        buffer.write(isGeneral
            ? '$gameName - सध्याची strategy: '
            : '$gameName screen पाहून: ');
        for (final s in strategies) {
          final move = s['move_or_situation'] as String;
          final strat = s['strategy'] as String;
          buffer.write('$move — $strat. ');
        }
        break;
      case 'hindi':
        buffer.write(isGeneral
            ? '$gameName - अभी की strategy: '
            : '$gameName screen देखकर: ');
        for (final s in strategies) {
          final move = s['move_or_situation'] as String;
          final strat = s['strategy'] as String;
          buffer.write('$move — $strat. ');
        }
        break;
      default:
        buffer.write(isGeneral
            ? '$gameName - Current strategy: '
            : 'Looking at $gameName screen: ');
        for (final s in strategies) {
          final move = s['move_or_situation'] as String;
          final strat = s['strategy'] as String;
          buffer.write('$move — $strat. ');
        }
    }
    return buffer.toString().trim();
  }

  String _noStrategyResponse(String gameName, String language) {
    switch (language) {
      case 'marathi':
        return '$gameName साठी अजून strategy save केली नाही. Game Knowledge मध्ये जाऊन strategies add करा.';
      case 'hindi':
        return '$gameName के लिए अभी strategy save नहीं है। Game Knowledge में जाकर strategies add करें।';
      default:
        return 'No strategies saved for $gameName yet. Go to Game Knowledge and add some strategies!';
    }
  }
}
