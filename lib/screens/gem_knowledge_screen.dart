import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../services/tts_service.dart';

class GameKnowledgeScreen extends StatefulWidget {
  const GameKnowledgeScreen({super.key});

  @override
  State<GameKnowledgeScreen> createState() => _GameKnowledgeScreenState();
}

class _GameKnowledgeScreenState extends State<GameKnowledgeScreen> {
  final GameService _game = GameService.instance;
  final TtsService _tts = TtsService.instance;

  List<String> _games = [];
  String? _selectedGame;
  List<Map<String, dynamic>> _strategies = [];

  final _gameCtrl = TextEditingController();
  final _moveCtrl = TextEditingController();
  final _strategyCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    final games = await _game.getSavedGames();
    setState(() => _games = games);
    if (_selectedGame != null) _loadStrategies(_selectedGame!);
  }

  Future<void> _loadStrategies(String gameName) async {
    final s = _searchCtrl.text.isEmpty
        ? await _game.getGameStrategies(gameName)
        : await _game.searchStrategies(gameName, _searchCtrl.text);
    setState(() => _strategies = s);
  }

  void _showAddDialog({String? prefilledGame}) {
    _gameCtrl.text = prefilledGame ?? _selectedGame ?? '';
    _moveCtrl.clear();
    _strategyCtrl.clear();
    _tagsCtrl.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Strategy Add करा 🎮',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(_gameCtrl, '🎮 Game चे नाव (e.g. Free Fire, BGMI)'),
            const SizedBox(height: 10),
            _field(_moveCtrl,
                '🕹️ Move / Situation (e.g. Enemy spotted, Low HP)'),
            const SizedBox(height: 10),
            _field(_strategyCtrl,
                '💡 Strategy / Plan (काय करायचं)', maxLines: 4),
            const SizedBox(height: 10),
            _field(_tagsCtrl,
                '🏷️ Tags (optional, e.g. rush, sniper, survive)'),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C3CE1)),
            onPressed: () async {
              if (_gameCtrl.text.isEmpty ||
                  _moveCtrl.text.isEmpty ||
                  _strategyCtrl.text.isEmpty) return;
              await _game.saveGameStrategy(
                gameName: _gameCtrl.text.trim(),
                moveOrSituation: _moveCtrl.text.trim(),
                strategy: _strategyCtrl.text.trim(),
                tags: _tagsCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              setState(() => _selectedGame = _gameCtrl.text.trim());
              await _loadGames();
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBulkImportDialog() {
    final ctrl = TextEditingController();
    final gameCtrl = TextEditingController(text: _selectedGame ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Bulk Import 📥',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(gameCtrl, 'Game नाव'),
            const SizedBox(height: 10),
            _field(
              ctrl,
              'ChatGPT/Gemini मधून copy केलेला strategy text paste करा\n\n'
              'Format:\nMove: Enemy spotted\nStrategy: Take cover behind rock, aim for head\n\n'
              'Move: Low HP\nStrategy: Run to safe zone, use medkit',
              maxLines: 10,
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C3CE1)),
            onPressed: () async {
              if (gameCtrl.text.isEmpty || ctrl.text.isEmpty) return;
              await _parseBulkImport(gameCtrl.text.trim(), ctrl.text);
              Navigator.pop(ctx);
              setState(() => _selectedGame = gameCtrl.text.trim());
              await _loadGames();
            },
            child: const Text('Import', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _parseBulkImport(String gameName, String text) async {
    // Parse "Move: ...\nStrategy: ..." blocks
    final lines = text.split('\n');
    String? currentMove;
    final stratLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().startsWith('move:') ||
          trimmed.toLowerCase().startsWith('situation:')) {
        if (currentMove != null && stratLines.isNotEmpty) {
          await _game.saveGameStrategy(
            gameName: gameName,
            moveOrSituation: currentMove,
            strategy: stratLines.join(' '),
          );
          stratLines.clear();
        }
        currentMove = trimmed.split(':').skip(1).join(':').trim();
      } else if (trimmed.toLowerCase().startsWith('strategy:') ||
          trimmed.toLowerCase().startsWith('plan:')) {
        stratLines.add(trimmed.split(':').skip(1).join(':').trim());
      } else if (trimmed.isNotEmpty && currentMove != null) {
        stratLines.add(trimmed);
      }
    }

    // Save last block
    if (currentMove != null && stratLines.isNotEmpty) {
      await _game.saveGameStrategy(
        gameName: gameName,
        moveOrSituation: currentMove,
        strategy: stratLines.join(' '),
      );
    }
  }

  Widget _field(TextEditingController c, String hint, {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Colors.white38, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF0D0D1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Game Knowledge 🎮',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _showBulkImportDialog,
            icon: const Icon(Icons.upload_file, color: Color(0xFF3CE1C3)),
            tooltip: 'Bulk Import',
          ),
          IconButton(
            onPressed: () => _showAddDialog(),
            icon: const Icon(Icons.add, color: Color(0xFF9B59F5)),
            tooltip: 'Add Strategy',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildGameTabs(),
          if (_selectedGame != null) _buildSearch(),
          Expanded(child: _buildStrategyList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C3CE1),
        onPressed: () => _showAddDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Strategy Add करा',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildGameTabs() {
    return Container(
      height: 50,
      color: const Color(0xFF1A1A2E),
      child: _games.isEmpty
          ? const Center(
              child: Text('अजून कोणताही game नाही',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _games.length,
              itemBuilder: (_, i) {
                final g = _games[i];
                final active = g == _selectedGame;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedGame = g);
                    _loadStrategies(g);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF6C3CE1)
                          : const Color(0xFF0D0D1A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active
                              ? const Color(0xFF9B59F5)
                              : Colors.white24),
                    ),
                    child: Text(g,
                        style: TextStyle(
                            color: active ? Colors.white : Colors.white54,
                            fontSize: 13,
                            fontWeight: active
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white),
        onChanged: (_) => _loadStrategies(_selectedGame!),
        decoration: InputDecoration(
          hintText: 'Move / situation search करा...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon:
              const Icon(Icons.search, color: Colors.white38),
          filled: true,
          fillColor: const Color(0xFF1A1A2E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildStrategyList() {
    if (_selectedGame == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_esports,
                size: 64, color: Colors.white12),
            const SizedBox(height: 16),
            const Text(
              'वर game tab select करा\nकिंवा नवीन strategy add करा',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white38, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C3CE1)),
              onPressed: () => _showAddDialog(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('पहिली Strategy Add करा',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_strategies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('$_selectedGame साठी कोणतीही strategy नाही.',
                style: TextStyle(color: Colors.white38)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C3CE1)),
              onPressed: () => _showAddDialog(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Strategy Add करा',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _strategies.length,
      itemBuilder: (_, i) => _strategyCard(_strategies[i]),
    );
  }

  Widget _strategyCard(Map<String, dynamic> s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF9B59F5).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF6C3CE1).withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.gamepad_outlined,
                    color: Color(0xFF9B59F5), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s['move_or_situation'] as String,
                    style: const TextStyle(
                        color: Color(0xFF9B59F5),
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['strategy'] as String,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13.5, height: 1.5),
                ),
                if ((s['tags'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: (s['tags'] as String)
                        .split(',')
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3CE1C3)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(t.trim(),
                                  style: const TextStyle(
                                      color: Color(0xFF3CE1C3),
                                      fontSize: 11)),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () =>
                          _tts.speak(s['strategy'] as String),
                      icon: const Icon(Icons.volume_up,
                          color: Color(0xFF9B59F5), size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () async {
                        await _game.deleteStrategy(s['id'] as int);
                        _loadStrategies(_selectedGame!);
                      },
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
