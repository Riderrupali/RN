import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../services/continuous_talk_service.dart';
import '../services/market_analysis_service.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/ocr_service.dart';
import '../services/database_service.dart';
import '../models/knowledge_model.dart';

class LiveTalkScreen extends StatefulWidget {
  const LiveTalkScreen({super.key});

  @override
  State<LiveTalkScreen> createState() => _LiveTalkScreenState();
}

class _LiveTalkScreenState extends State<LiveTalkScreen> {
  final ContinuousTalkService _talk = ContinuousTalkService.instance;
  final MarketAnalysisService _market = MarketAnalysisService.instance;
  final TtsService _tts = TtsService.instance;
  final SttService _stt = SttService.instance;
  final OcrService _ocr = OcrService.instance;
  final TextEditingController _textCtrl = TextEditingController();

  bool _isListening = false;
  bool _isAnalyzing = false;
  String _lastResponse = '';
  final List<_TalkEntry> _log = [];

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
    _talk.start(language: _langCode);
    _welcome();
  }

  @override
  void dispose() {
    _talk.stop();
    super.dispose();
  }

  Future<void> _welcome() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final msg = _langCode == 'marathi'
        ? 'Live Talk चालू आहे! Screen द्या, text द्या किंवा बोला — मी नेहमी बोलत राहीन.'
        : _langCode == 'hindi'
            ? 'Live Talk चालू है! Screen दें, text दें या बोलें — मैं बोलता रहूंगा।'
            : 'Live Talk is ON! Give me screen, text or speak — I\'ll keep talking.';
    _addToLog(msg, isAi: true);
    await _tts.speak(msg);
  }

  Future<void> _processText(String text) async {
    if (text.trim().isEmpty) return;
    _addToLog(text, isAi: false);
    setState(() => _isAnalyzing = true);

    final response = await _talk.processUserText(text, _langCode);
    final finalResp = response.isNotEmpty ? response : _getIdleResponse();

    setState(() {
      _lastResponse = finalResp;
      _isAnalyzing = false;
    });
    _addToLog(finalResp, isAi: true);
    await _tts.speak(finalResp);
  }

  Future<void> _analyzeImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;

    setState(() => _isAnalyzing = true);
    final ocrText = await _ocr.extractTextFromPath(picked.path);

    _addToLog('📷 Screen image दिलं', isAi: false);
    await _talk.onNewScreenText(ocrText, _langCode);

    final isMarket = _market.isMarketScreen(ocrText);
    String response;
    if (isMarket) {
      response = await _market.analyzeMarketScreen(ocrText, _langCode);
    } else {
      response = await _talk.processUserText(ocrText, _langCode);
    }

    if (response.isEmpty) response = _getNoMatchResponse(ocrText);

    setState(() {
      _lastResponse = response;
      _isAnalyzing = false;
    });
    _addToLog(response, isAi: true);
    await _tts.speak(response);
  }

  void _toggleMic() async {
    if (_isListening) {
      await _stt.stopListening();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _stt.startListening(
        onResult: (text) {
          setState(() => _isListening = false);
          if (text.isNotEmpty) _processText(text);
        },
        localeId: _stt.localeFor(_langCode),
      );
    }
  }

  void _addToLog(String text, {required bool isAi}) {
    setState(() {
      _log.insert(0, _TalkEntry(text: text, isAi: isAi, time: DateTime.now()));
      if (_log.length > 50) _log.removeLast();
    });
  }

  String _getIdleResponse() {
    switch (_langCode) {
      case 'marathi':
        return 'मी ऐकतोय! आणखी माहिती द्या किंवा screen दाखवा.';
      case 'hindi':
        return 'मैं सुन रहा हूँ! और जानकारी दें या screen दिखाएं।';
      default:
        return 'I\'m listening! Give me more info or show the screen.';
    }
  }

  String _getNoMatchResponse(String ocrText) {
    final preview = ocrText.trim().isEmpty
        ? 'screen'
        : '"${ocrText.trim().substring(0, ocrText.trim().length.clamp(0, 40))}..."';
    switch (_langCode) {
      case 'marathi':
        return 'Screen वर $preview दिसतंय. याबद्दल माझ्याकडे माहिती नाही. chat मध्ये upload करा.';
      case 'hindi':
        return 'Screen पर $preview दिख रहा है। इसके बारे में जानकारी नहीं। chat में upload करें।';
      default:
        return 'I see $preview on screen but I don\'t have info about this yet. Upload in chat!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Row(
          children: [
            const Text('Live Talk 🔴', style: TextStyle(color: Colors.white)),
            const SizedBox(width: 10),
            if (_talk.isActive)
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF3CE1C3),
                  shape: BoxShape.circle,
                ),
              ).animate(onPlay: (c) => c.repeat())
                  .fadeOut(duration: 800.ms)
                  .then()
                  .fadeIn(duration: 800.ms),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          StatefulBuilder(
            builder: (ctx, setS) => IconButton(
              onPressed: () { _tts.toggleMute(); setS(() {}); },
              icon: Icon(
                _tts.isMuted ? Icons.volume_off : Icons.volume_up,
                color: _tts.isMuted ? Colors.redAccent : const Color(0xFF9B59F5),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBar(),
          Expanded(child: _buildLog()),
          if (_isAnalyzing) _buildThinking(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1A1A2E),
      child: Row(
        children: [
          const Icon(Icons.circle, color: Color(0xFF3CE1C3), size: 10),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _langCode == 'marathi'
                  ? 'नेहमी चालू — screen द्या, text द्या किंवा बोला'
                  : _langCode == 'hindi'
                      ? 'हमेशा चालू — screen दें, text दें या बोलें'
                      : 'Always ON — give screen, text or speak',
              style: const TextStyle(color: Color(0xFF3CE1C3), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLog() {
    if (_log.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.record_voice_over,
                size: 60, color: const Color(0xFF9B59F5).withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              _langCode == 'marathi'
                  ? 'बोला, text टाइप करा\nकिंवा screen image द्या'
                  : _langCode == 'hindi'
                      ? 'बोलें, text type करें\nया screen image दें'
                      : 'Speak, type text\nor give screen image',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 15, height: 1.6),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _log.length,
      itemBuilder: (_, i) => _buildEntry(_log[i]),
    );
  }

  Widget _buildEntry(_TalkEntry entry) {
    return Align(
      alignment: entry.isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          gradient: entry.isAi
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF6C3CE1), Color(0xFF9B59F5)]),
          color: entry.isAi ? const Color(0xFF1A1A2E) : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(entry.isAi ? 4 : 16),
            bottomRight: Radius.circular(entry.isAi ? 16 : 4),
          ),
          border: entry.isAi
              ? Border.all(color: const Color(0xFF9B59F5).withOpacity(0.2))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.isAi)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(Icons.auto_awesome, size: 12, color: Color(0xFF9B59F5)),
                  SizedBox(width: 4),
                  Text('Code Magic',
                      style: TextStyle(color: Color(0xFF9B59F5), fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            Text(
              entry.text,
              style: TextStyle(
                color: entry.isAi ? Colors.white : Colors.white,
                fontSize: 14,
                height: 1.55,
              ),
            ),
            if (entry.isAi)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: () => _tts.speak(entry.text),
                  child: const Row(children: [
                    Icon(Icons.replay, color: Color(0xFF3CE1C3), size: 13),
                    SizedBox(width: 4),
                    Text('पुन्हा ऐका',
                        style: TextStyle(color: Color(0xFF3CE1C3), fontSize: 11)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThinking() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.psychology, color: Color(0xFF9B59F5), size: 16),
                SizedBox(width: 8),
                Text('Analyze करतोय...',
                    style: TextStyle(color: Color(0xFF9B59F5), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: const Color(0xFF1A1A2E),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image buttons row
          Row(
            children: [
              _imgBtn(Icons.photo_library_outlined, 'Gallery',
                  () => _analyzeImage(ImageSource.gallery),
                  const Color(0xFF6C3CE1)),
              const SizedBox(width: 8),
              _imgBtn(Icons.camera_alt_outlined, 'Camera',
                  () => _analyzeImage(ImageSource.camera),
                  const Color(0xFF3CE1C3)),
            ],
          ),
          const SizedBox(height: 8),
          // Text input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: _langCode == 'marathi'
                        ? 'Text टाइप करा किंवा paste करा...'
                        : _langCode == 'hindi'
                            ? 'Text type करें या paste करें...'
                            : 'Type or paste text...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0D0D1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (t) { _textCtrl.clear(); _processText(t); },
                ),
              ),
              const SizedBox(width: 8),
              // Mic
              GestureDetector(
                onTap: _toggleMic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? const Color(0xFF3CE1C3)
                        : const Color(0xFF6C3CE1),
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.white, size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send
              GestureDetector(
                onTap: () {
                  final t = _textCtrl.text;
                  _textCtrl.clear();
                  _processText(t);
                },
                child: Container(
                  width: 46, height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF6C3CE1),
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imgBtn(IconData icon, String label, VoidCallback onTap, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TalkEntry {
  final String text;
  final bool isAi;
  final DateTime time;
  _TalkEntry({required this.text, required this.isAi, required this.time});
}
