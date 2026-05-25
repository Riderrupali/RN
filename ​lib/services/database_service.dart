import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/knowledge_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  Database? _db;

  DatabaseService._internal();

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'code_magic.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS knowledge (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic TEXT NOT NULL,
        content TEXT NOT NULL,
        app_name TEXT,
        language TEXT DEFAULT 'any',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // Save knowledge (supports any language — Marathi, Hindi, English)
  Future<int> saveKnowledge(KnowledgeItem item) async {
    return await _db!.insert(
      'knowledge',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<KnowledgeItem>> getAllKnowledge() async {
    final maps = await _db!.query('knowledge', orderBy: 'created_at DESC');
    return maps.map((m) => KnowledgeItem.fromMap(m)).toList();
  }

  // Full Unicode-safe search — works for Marathi/Hindi text
  Future<List<KnowledgeItem>> searchKnowledge(String query) async {
    if (query.trim().isEmpty) return getAllKnowledge();

    final q = query.trim();

    // Direct LIKE search — SQLite stores UTF-8, so Marathi text works
    final maps = await _db!.rawQuery(
      '''SELECT * FROM knowledge
         WHERE topic LIKE ? OR content LIKE ? OR app_name LIKE ?
         ORDER BY
           CASE WHEN topic LIKE ? THEN 0 ELSE 1 END,
           created_at DESC
         LIMIT 20''',
      ['%$q%', '%$q%', '%$q%', '%$q%'],
    );
    if (maps.isNotEmpty) {
      return maps.map((m) => KnowledgeItem.fromMap(m)).toList();
    }

    // Word-by-word fallback — split on spaces (works for Devanagari too)
    final words = q
        .split(RegExp(r'[\s\n,।]+'))
        .where((w) => w.trim().length > 1)
        .toList();

    final allResults = <KnowledgeItem>[];
    final seenIds = <int>{};

    for (final word in words.take(6)) {
      final wordMaps = await _db!.rawQuery(
        '''SELECT * FROM knowledge
           WHERE topic LIKE ? OR content LIKE ? OR app_name LIKE ?
           LIMIT 5''',
        ['%$word%', '%$word%', '%$word%'],
      );
      for (final m in wordMaps) {
        final item = KnowledgeItem.fromMap(m);
        if (seenIds.add(item.id ?? 0)) allResults.add(item);
      }
    }
    return allResults;
  }

  Future<void> deleteKnowledge(int id) async {
    await _db!.delete('knowledge', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> saveChatMessage(ChatMessage message) async {
    return await _db!.insert('chat_history', message.toMap());
  }

  Future<List<ChatMessage>> getRecentChats({int limit = 60}) async {
    final maps = await _db!.query(
      'chat_history',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map((m) => ChatMessage.fromMap(m)).toList().reversed.toList();
  }

  Future<void> clearChat() async {
    await _db!.delete('chat_history');
  }
}
