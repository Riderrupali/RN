import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/ocr_service.dart';
import '../services/screen_monitor_service.dart';
import '../services/tts_service.dart';

class ScreenReadScreen extends StatefulWidget {
  const ScreenReadScreen({super.key});

  @override
  State<ScreenReadScreen> createState() => _ScreenReadScreenState();
}

class _ScreenReadScreenState extends State<ScreenReadScreen> {
  final OcrService _ocr = OcrService.instance;
  final ScreenMonitorService _monitor = ScreenMonitorService.instance;
  final TtsService _tts = TtsService.instance;

  String _ocrText = '';
  String _aiResponse = '';
  bool _isProcessing = false;

  String get _langCode {
    switch (_tts.language) {
      case AppLanguage.hindi:
        return 'hindi';
      case AppLanguage.marathi:
        return 'marathi';
      default:
        return 'english';
    }
  }

  Future<void> _pickAndReadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isProcessing = true);
    final text = await _ocr.extractTextFromPath(picked.path);
    final response = await _monitor.analyzeScreenText(text, _langCode);

    setState(() {
      _ocrText = text;
      _aiResponse = response;
      _isProcessing = false;
    });

    if (response.isNotEmpty) {
      await _tts.speak(response);
    }
  }

  Future<void> _takeScreenshot() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    setState(() => _isProcessing = true);
    final text = await _ocr.extractTextFromPath(picked.path);
    final response = await _monitor.analyzeScreenText(text, _langCode);

    setState(() {
      _ocrText = text;
      _aiResponse = response;
      _isProcessing = false;
    });

    if (response.isNotEmpty) {
      await _tts.speak(response);
    }
  }

  Future<void> _pasteAndAnalyze(String pastedText) async {
    if (pastedText.trim().isEmpty) return;
    setState(() {
      _isProcessing = true;
      _ocrText = pastedText;
    });

    final response = await _monitor.analyzeScreenText(pastedText, _langCode);
    setState(() {
      _aiResponse = response;
      _isProcessing = false;
    });

    if (response.isNotEmpty) {
      await _tts.speak(response);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Screen Reader',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoCard(),
            const SizedBox(height: 20),
            _actionButtons(),
            const SizedBox(height: 20),
            _pasteSection(),
            if (_isProcessing) ...[
              const SizedBox(height: 24),
              const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF9B59F5)),
              ),
            ],
            if (_ocrText.isNotEmpty) ...[
              const SizedBox(height: 24),
              _resultSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF3CE1C3).withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF3CE1C3), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Screen चा screenshot घ्या किंवा image upload करा. '
              'OCR ने text वाचेल आणि तुमच्या saved knowledge मधून answer देईल.',
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: _actionBtn(
            Icons.photo_library_outlined,
            'Gallery\nमधून',
            _pickAndReadImage,
            const Color(0xFF6C3CE1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionBtn(
            Icons.camera_alt_outlined,
            'Camera\nने',
            _takeScreenshot,
            const Color(0xFF3CE1C3),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(
      IconData icon, String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: color, fontSize: 13, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _pasteSection() {
    final ctrl = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('किंवा Text paste करा:',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Screen वरील text paste करा...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF1A1A2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C3CE1),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _pasteAndAnalyze(ctrl.text),
            icon:
                const Icon(Icons.search, color: Colors.white),
            label: const Text('Analyze करा',
                style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _resultSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📱 Screen मधील Text:',
            style: TextStyle(
                color: Color(0xFF9B59F5),
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(_ocrText,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.5)),
        ),
        if (_aiResponse.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('🤖 Code Magic म्हणतो:',
              style: TextStyle(
                  color: Color(0xFF3CE1C3),
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3CE1C3).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF3CE1C3).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_aiResponse,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.6)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _tts.speak(_aiResponse),
                  child: const Row(
                    children: [
                      Icon(Icons.volume_up,
                          color: Color(0xFF3CE1C3), size: 18),
                      SizedBox(width: 6),
                      Text('पुन्हा ऐका',
                          style: TextStyle(
                              color: Color(0xFF3CE1C3),
                              fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
