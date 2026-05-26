import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../services/game_service.dart';
import '../services/tts_service.dart';
import '../services/ocr_service.dart';
import '../services/screen_monitor_service.dart';
import 'game_knowledge_screen.dart';

class GameModeScreen extends StatefulWidget {
  const GameModeScreen({super.key});

  @override
  State<GameModeScreen> createState() => _GameModeScreenState();
}

class _GameModeScreenState extends State<GameModeScreen> {
  final GameService _game = GameService.instance;
  final TtsService _tts = TtsService.instance;
  final OcrService _ocr = OcrService.instance;
  final ScreenMonitorService _monitor = ScreenMonitorService.instance;

  List<String> _savedGames = [];
  String? _activeGame;
  String _lastStrategy = '';
  String _lastOcrText = '';
  bool _isAnalyzing = false;
  bool _gameMonitorActive = false;
  final List<String> _strategyLog = [];

  String get _langCode {
    switch (_tts.language) {
      case AppLanguage.hindi: return 'hindi';
      case AppLanguage.marathi: return 'marathi';
      default: return 'english';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  @override
  void dispose() {
    _game.stopGameMonitor();
    super.dispose();
  }

  Future<void> _loadGames() async {
    final games = await _game.getSavedGames();
    setState(() => _savedGames = games);
  }

  Future<void> _analyzeScreenshot() async {
    if (_activeGame == null) {
      _showSelectGameDialog();
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isAnalyzing = true);
    final ocrText = await _ocr.extractTextFromPath(picked.path);
    final strategy = await _game.getStrategyFromScreen(
      ocrText, _activeGame!, _langCode);

    setState(() {
      _lastOcrText = ocrText;
      _lastStrategy = strategy;
      _isAnalyzing = false;
      if (strategy.isNotEmpty) _strategyLog.insert(0, strategy);
    });
    await _tts.speak(strategy);
  }

  Future<void> _analyzeCamera() async {
    if (_activeGame == null) {
      _showSelectGameDialog();
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    setState(() => _isAnalyzing = true);
    final ocrText = await _ocr.extractTextFromPath(picked.path);
    final strategy = await _game.getStrategyFromScreen(
      ocrText, _activeGame!, _langCode);

    setState(() {
      _lastOcrText = ocrText;
      _lastStrategy = strategy;
      _isAnalyzing = false;
      if (strategy.isNotEmpty) _strategyLog.insert(0, strategy);
    });
    await _tts.speak(strategy);
  }

  Future<void> _pasteAndAnalyze(String text) async {
    if (_activeGame == null) {
      _showSelectGameDialog();
      return;
    }
    if (text.trim().isEmpty) return;

    setState(() => _isAnalyzing = true);
    final strategy = await _game.getStrategyFromScreen(
      text, _activeGame!, _langCode);

    setState(() {
      _lastOcrText = text;
      _lastStrategy = strategy;
      _isAnalyzing = false;
      if (strategy.isNotEmpty) _strategyLog.insert(0, strategy);
    });
    await _tts.speak(strategy);
  }

  void _toggleGameMonitor() async {
    if (_activeGame == null) {
      _showSelectGameDialog();
      return;
    }

    if (_gameMonitorActive) {
      _game.stopGameMonitor();
      setState(() => _gameMonitorActive = false);
      await _tts.speak(_langCode == 'marathi'
          ? 'Game monitor बंद केलं.'
          : _langCode == 'hindi' ? 'Game monitor बंद।' : 'Game monitor off.');
    } else {
      _game.startGameMonitor(
        gameName: _activeGame!,
        language: _langCode,
        onStrategy: (strategy) async {
          setState(() {
            _lastStrategy = strategy;
            _strategyLog.insert(0, strategy);
          });
          await _tts.speak(strategy);
        },
      );
      setState(() => _gameMonitorActive = true);
      await _tts.speak(_langCode == 'marathi'
          ? 'Game monitor चालू केलं. Screen बदलेल तेव्हा strategy सांगेन.'
          : _langCode == 'hindi'
              ? 'Game monitor चालू। Screen बदलने पर strategy बताऊंगा।'
              : 'Game monitor on. I\'ll give strategy when screen changes.');
    }
  }

  void _showSelectGameDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Game Select करा',
            style: TextStyle(color: Colors.white)),
        content: _savedGames.isEmpty
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                  'कोणताही game save नाही.\nआधी Game Knowledge मध्ये game add करा.',
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C3CE1)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GameKnowledgeScreen()));
                  },
                  child: const Text('Game Add करा',
                      style: TextStyle(color: Colors.white)),
                )
              ])
            : SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: _savedGames
                      .map((g) => ListTile(
                            title: Text(g,
                                style: const TextStyle(color: Colors.white)),
                            leading: const Icon(Icons.sports_esports,
                                color: Color(0xFF9B59F5)),
                            onTap: () {
                              setState(() => _activeGame = g);
                              Navigator.pop(ctx);
                            },
                          ))
                      .toList(),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Game Mode 🎮',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const GameKnowledgeScreen()))
                .then((_) => _loadGames()),
            icon: const Icon(Icons.menu_book_outlined, color: Color(0xFF9B59F5)),
            tooltip: 'Game Knowledge',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildGameSelector(),
          _buildMonitorToggle(),
          Expanded(child: _buildStrategyPanel()),
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildGameSelector() {
    return GestureDetector(
      onTap: _showSelectGameDialog,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _activeGame != null
                  ? const Color(0xFF9B59F5)
                  : Colors.white24),
        ),
        child: Row(
          children: [
            const Icon(Icons.sports_esports, color: Color(0xFF9B59F5)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _activeGame ?? 'Game Select करा →',
                style: TextStyle(
                  color: _activeGame != null ? Colors.white : Colors.white38,
                  fontSize: 16,
                  fontWeight: _activeGame != null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: _activeGame != null
                  ? const Color(0xFF9B59F5)
                  : Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitorToggle() {
    if (_activeGame == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _gameMonitorActive
            ? const Color(0xFF3CE1C3).withOpacity(0.1)
            : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _gameMonitorActive
              ? const Color(0xFF3CE1C3).withOpacity(0.5)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _gameMonitorActive ? Icons.visibility : Icons.visibility_off,
            color: _gameMonitorActive
                ? const Color(0xFF3CE1C3)
                : Colors.white38,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _gameMonitorActive
                  ? 'Screen Monitor चालू — strategy येईल'
                  : 'Auto Screen Monitor बंद आहे',
              style: TextStyle(
                color: _gameMonitorActive
                    ? const Color(0xFF3CE1C3)
                    : Colors.white38,
                fontSize: 13,
              ),
            ),
          ),
          Switch(
            value: _gameMonitorActive,
            activeColor: const Color(0xFF3CE1C3),
            onChanged: (_) => _toggleGameMonitor(),
          ),
        ],
      ),
    )
        .animate(
            target: _gameMonitorActive ? 1 : 0,
            onPlay: (c) => _gameMonitorActive ? c.repeat() : c.stop())
        .shimmer(
            duration: 2.seconds, color: const Color(0xFF3CE1C3).withOpacity(0.2));
  }

  Widget _buildStrategyPanel() {
    if (_isAnalyzing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF9B59F5)),
            SizedBox(height: 16),
            Text('Screen analyze करतोय...',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    if (_lastStrategy.isNotEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Strategy
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D1B69), Color(0xFF1A1A2E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: const Color(0xFF9B59F5).withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          color: Color(0xFF9B59F5), size: 18),
                      SizedBox(width: 8),
                      Text('Strategy:',
                          style: TextStyle(
                              color: Color(0xFF9B59F5),
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _lastStrategy,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => _tts.speak(_lastStrategy),
                    child: const Row(
                      children: [
                        Icon(Icons.volume_up,
                            color: Color(0xFF3CE1C3), size: 16),
                        SizedBox(width: 6),
                        Text('पुन्हा ऐका',
                            style: TextStyle(
                                color: Color(0xFF3CE1C3), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // OCR Screen text
            if (_lastOcrText.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('📱 Screen वर दिसलेलं:',
                  style:
                      TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _lastOcrText.length > 200
                      ? '${_lastOcrText.substring(0, 200)}...'
                      : _lastOcrText,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12, height: 1.4),
                ),
              ),
            ],

            // Strategy log
            if (_strategyLog.length > 1) ...[
              const SizedBox(height: 20),
              const Text('📜 मागील Strategies:',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._strategyLog.skip(1).take(5).map(
                    (s) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        s.length > 120 ? '${s.substring(0, 120)}...' : s,
                        style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_esports,
              size: 64,
              color: const Color(0xFF9B59F5).withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            _activeGame == null
                ? 'आधी game select करा'
                : 'Screen चा screenshot द्या\nकिंवा Auto Monitor चालू करा',
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: Colors.white38, fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    final pasteCtrl = TextEditingController();
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF1A1A2E),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  Icons.photo_library_outlined,
                  'Gallery',
                  _analyzeScreenshot,
                  const Color(0xFF6C3CE1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionBtn(
                  Icons.camera_alt_outlined,
                  'Camera',
                  _analyzeCamera,
                  const Color(0xFF3CE1C3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionBtn(
                  Icons.paste_outlined,
                  'Paste',
                  () => _showPasteDialog(pasteCtrl),
                  const Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
      IconData icon, String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showPasteDialog(TextEditingController ctrl) {
    ctrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Screen Text Paste करा',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Game screen वरील text paste करा...',
            hintStyle: TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Color(0xFF0D0D1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide.none,
            ),
          ),
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
            onPressed: () {
              Navigator.pop(ctx);
              _pasteAndAnalyze(ctrl.text);
            },
            child:
                const Text('Analyze', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
