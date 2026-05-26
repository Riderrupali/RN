import 'package:flutter/material.dart';
import '../services/tts_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TtsService _tts = TtsService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('🌐 Language / भाषा'),
          const SizedBox(height: 12),
          _languageSelector(),
          const SizedBox(height: 24),
          _sectionTitle('🎙️ Voice Type'),
          const SizedBox(height: 12),
          _voiceSelector(),
          const SizedBox(height: 24),
          _sectionTitle('🔇 Mute'),
          const SizedBox(height: 12),
          _muteToggle(),
          const SizedBox(height: 24),
          _sectionTitle('ℹ️ About'),
          const SizedBox(height: 12),
          _aboutCard(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          color: Color(0xFF9B59F5), fontSize: 15, fontWeight: FontWeight.bold),
    );
  }

  Widget _languageSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _langOption('🇺🇸 English', AppLanguage.english),
          _langOption('🇮🇳 हिंदी (Hindi)', AppLanguage.hindi),
          _langOption('🇮🇳 मराठी (Marathi)', AppLanguage.marathi),
        ],
      ),
    );
  }

  Widget _langOption(String label, AppLanguage lang) {
    return RadioListTile<AppLanguage>(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      value: lang,
      groupValue: _tts.language,
      activeColor: const Color(0xFF9B59F5),
      onChanged: (val) async {
        if (val != null) {
          await _tts.setLanguage(val);
          setState(() {});
          await _tts.speak(_tts.languageGreeting);
        }
      },
    );
  }

  Widget _voiceSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _voiceOption('👨 Male / पुरुष', VoiceType.male),
          _voiceOption('👩 Female / महिला', VoiceType.female),
          _voiceOption('🧒 Child / मुल', VoiceType.child),
        ],
      ),
    );
  }

  Widget _voiceOption(String label, VoiceType type) {
    return RadioListTile<VoiceType>(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      value: type,
      groupValue: _tts.voiceType,
      activeColor: const Color(0xFF9B59F5),
      onChanged: (val) async {
        if (val != null) {
          await _tts.setVoiceType(val);
          setState(() {});
          await _tts.speak('Voice changed!');
        }
      },
    );
  }

  Widget _muteToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        title: const Text('Mute Voice', style: TextStyle(color: Colors.white)),
        subtitle: Text(
          _tts.isMuted ? 'Voice is OFF' : 'Voice is ON',
          style: TextStyle(
              color: _tts.isMuted ? Colors.redAccent : const Color(0xFF3CE1C3)),
        ),
        value: _tts.isMuted,
        activeColor: const Color(0xFF9B59F5),
        onChanged: (val) {
          _tts.toggleMute();
          setState(() {});
        },
      ),
    );
  }

  Widget _aboutCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9B59F5).withOpacity(0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Code Magic',
              style: TextStyle(
                  color: Color(0xFF9B59F5),
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'Your personal offline AI friend.\n'
            '• Speaks English, Hindi & Marathi\n'
            '• Learns from your text files\n'
            '• Reads screen with OCR\n'
            '• Works 100% offline',
            style: TextStyle(color: Colors.white60, height: 1.6),
          ),
          SizedBox(height: 12),
          Text('Version 1.0.0',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}
