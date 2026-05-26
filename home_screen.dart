import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/screen_monitor_service.dart';
import 'chat_screen.dart';
import 'knowledge_screen.dart';
import 'settings_screen.dart';
import 'screen_read_screen.dart';
import 'game_mode_screen.dart';
import 'live_talk_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TtsService _tts = TtsService.instance;
  final SttService _stt = SttService.instance;
  final ScreenMonitorService _monitor = ScreenMonitorService.instance;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _stt.init();
    await Future.delayed(const Duration(milliseconds: 800));
    await _tts.speak(_tts.languageGreeting);
  }

  @override
  void dispose() {
    _monitor.stopMonitoring();
    super.dispose();
  }

  Future<void> _toggleListen() async {
    if (_isListening) {
      await _stt.stopListening();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _stt.startListening(
        onResult: (text) {
          setState(() => _isListening = false);
          if (text.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(initialMessage: text),
              ),
            );
          }
        },
        localeId: _stt.localeFor(
          _tts.language == AppLanguage.hindi
              ? 'hindi'
              : _tts.language == AppLanguage.marathi
                  ? 'marathi'
                  : 'english',
        ),
      );
    }
  }

  Future<void> _toggleScreenMonitor() async {
    if (_monitor.isMonitoring) {
      _monitor.stopMonitoring();
      setState(() {});
      final msg = _tts.language == AppLanguage.marathi
          ? 'Screen monitoring बंद केलं.'
          : _tts.language == AppLanguage.hindi
              ? 'Screen monitoring बंद हो गई।'
              : 'Screen monitoring stopped.';
      await _tts.speak(msg);
    } else {
      await _monitor.startMonitoring();
      setState(() {});
      final msg = _tts.language == AppLanguage.marathi
          ? 'Screen monitoring चालू केलं. तुमची screen पाहतो आणि saved माहितीनुसार सांगेन.'
          : _tts.language == AppLanguage.hindi
              ? 'Screen monitoring शुरू हो गई। आपकी screen देख रहा हूँ।'
              : 'Screen monitoring started. I\'ll watch your screen and help using your saved knowledge.';
      await _tts.speak(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Spacer(),
            _buildScreenMonitorBadge(),
            const SizedBox(height: 16),
            _buildMagicOrb(),
            const SizedBox(height: 20),
            _buildStatusText(),
            const Spacer(),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Code Magic',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  foreground: Paint()
                    ..shader = const LinearGradient(
                      colors: [Color(0xFF9B59F5), Color(0xFF3CE1C3)],
                    ).createShader(const Rect.fromLTWH(0, 0, 200, 50)),
                ),
              ),
              const Text(
                'Your Personal AI Friend',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
          Row(
            children: [
              // Screen Monitor Toggle
              StatefulBuilder(
                builder: (ctx, setS) => IconButton(
                  onPressed: () async {
                    await _toggleScreenMonitor();
                    setS(() {});
                  },
                  tooltip: 'Screen Monitor',
                  icon: Icon(
                    Icons.screen_search_desktop_outlined,
                    color: _monitor.isMonitoring
                        ? const Color(0xFF3CE1C3)
                        : Colors.white38,
                  ),
                ),
              ),
              // Mute toggle
              StatefulBuilder(
                builder: (ctx, setS) => IconButton(
                  onPressed: () {
                    _tts.toggleMute();
                    setS(() {});
                  },
                  icon: Icon(
                    _tts.isMuted ? Icons.volume_off : Icons.volume_up,
                    color: _tts.isMuted
                        ? Colors.redAccent
                        : const Color(0xFF9B59F5),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
                icon: const Icon(Icons.settings, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScreenMonitorBadge() {
    if (!_monitor.isMonitoring) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3CE1C3).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3CE1C3).withOpacity(0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility, color: Color(0xFF3CE1C3), size: 16),
          SizedBox(width: 8),
          Text(
            'Screen पाहतोय — Knowledge वापरून सांगेन',
            style: TextStyle(color: Color(0xFF3CE1C3), fontSize: 12),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 2.seconds,
          color: const Color(0xFF3CE1C3).withOpacity(0.3),
        );
  }

  Widget _buildMagicOrb() {
    return GestureDetector(
      onTap: _toggleListen,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _isListening ? 160 : 140,
        height: _isListening ? 160 : 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: _isListening
                ? [const Color(0xFF3CE1C3), const Color(0xFF6C3CE1)]
                : [const Color(0xFF9B59F5), const Color(0xFF3B1FA8)],
          ),
          boxShadow: [
            BoxShadow(
              color: (_isListening
                      ? const Color(0xFF3CE1C3)
                      : const Color(0xFF9B59F5))
                  .withOpacity(0.6),
              blurRadius: _isListening ? 60 : 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Icon(
          _isListening ? Icons.mic : Icons.mic_none,
          size: 60,
          color: Colors.white,
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 2.seconds, color: Colors.white24),
    );
  }

  Widget _buildStatusText() {
    return Text(
      _isListening ? 'Listening...' : 'Tap to speak',
      style: TextStyle(
        color: _isListening ? const Color(0xFF3CE1C3) : Colors.white38,
        fontSize: 16,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF9B59F5).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.chat_bubble_outline, 'Chat', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ChatScreen()));
          }),
          _navItem(Icons.record_voice_over_outlined, 'Live', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LiveTalkScreen()));
          }),
          _navItem(Icons.sports_esports_outlined, 'Game', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const GameModeScreen()));
          }),
          _navItem(Icons.auto_stories_outlined, 'Knowledge', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const KnowledgeScreen()));
          }),
          _navItem(Icons.screen_search_desktop_outlined, 'Screen', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ScreenReadScreen()));
          }),
          _navItem(Icons.settings_outlined, 'Settings', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF9B59F5), size: 26),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}
