import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/database_service.dart';
import '../models/knowledge_model.dart';
import '../widgets/chat_bubble.dart';
import 'screen_read_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? initialMessage;
  const ChatScreen({super.key, this.initialMessage});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final AiService _ai = AiService.instance;
  final TtsService _tts = TtsService.instance;
  final SttService _stt = SttService.instance;

  List<ChatMessage> _messages = [];
  bool _isListening = false;
  bool _isProcessing = false;

  // --- Teach Mode ---
  bool _teachMode = false;

  // --- Fallback save flow ---
  bool _awaitingSave = false;
  String _pendingSaveTopic = '';
  String? _pendingAppName;

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

  @override
  void initState() {
    super.initState();
    _loadHistory();
    if (widget.initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _processInput(widget.initialMessage!);
      });
    }
  }

  Future<void> _loadHistory() async {
    final msgs = await DatabaseService.instance.getRecentChats();
    setState(() => _messages = msgs);
    _scrollToBottom();
  }

  // ---------------------------------------------------------------
  // CORE: process every message
  // ---------------------------------------------------------------
  Future<void> _processInput(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _isProcessing = true);

    final userMsg =
        ChatMessage(text: text, isUser: true, createdAt: DateTime.now());
    await DatabaseService.instance.saveChatMessage(userMsg);
    setState(() => _messages.add(userMsg));
    _scrollToBottom();

    String response;

    // ---- TEACH MODE: auto-save every message as knowledge ----
    if (_teachMode) {
      response = await _ai.teachAndSave(text, _langCode);
    }

    // ---- Fallback save: user provided content after app asked ----
    else if (_awaitingSave) {
      await _ai.saveNewKnowledge(_pendingSaveTopic, text, _pendingAppName);
      response = _langCode == 'marathi'
          ? '✅ छान! "${_pendingSaveTopic}" बद्दलची माहिती save केली!\n'
            'आता मला तुम्ही विचाराल तेव्हा मी हे सांगेन. 😊'
          : _langCode == 'hindi'
              ? '✅ बढ़िया! "${_pendingSaveTopic}" की जानकारी save हुई!\n'
                'अगली बार पूछोगे तो बताऊंगा।'
              : '✅ Saved "${_pendingSaveTopic}"!\nI\'ll use this next time you ask.';
      _awaitingSave = false;
      _pendingSaveTopic = '';
      _pendingAppName = null;
    }

    // ---- Screen read command ----
    else if (_isScreenReadCommand(text)) {
      setState(() => _isProcessing = false);
      if (mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ScreenReadScreen()));
      }
      return;
    }

    // ---- Normal conversation ----
    else {
      response = await _ai.getResponse(text, _langCode);

      if (response == '__MUTE__') {
        _tts.toggleMute();
        response = _langCode == 'marathi'
            ? 'Mute केलं.'
            : _langCode == 'hindi'
                ? 'Mute कर दिया।'
                : 'Muted.';
      } else if (response == '__UNMUTE__') {
        if (_tts.isMuted) _tts.toggleMute();
        response = _langCode == 'marathi'
            ? 'Unmute केलं.'
            : _langCode == 'hindi'
                ? 'Unmute कर दिया।'
                : 'Unmuted.';
      } else if (response == '__TEACH_ON__') {
        setState(() => _teachMode = true);
        response = _langCode == 'marathi'
            ? '📚 शिकवा Mode चालू! आता तुम्ही जे सांगाल ते मी शिकेन.\n'
              'Trading, Game, कोणतीही माहिती Marathi मध्ये लिहा — मी save करतो!'
            : _langCode == 'hindi'
                ? '📚 Teach Mode चालू! अब जो बताओगे वो सीखूंगा।'
                : '📚 Teach Mode ON! Tell me anything and I\'ll save it.';
      } else if (response == '__TEACH_OFF__') {
        setState(() => _teachMode = false);
        response = _langCode == 'marathi'
            ? '✅ शिकवा Mode बंद. Normal chat चालू.'
            : _langCode == 'hindi'
                ? '✅ Teach Mode बंद। Normal chat चालू।'
                : '✅ Teach Mode OFF. Normal chat resumed.';
      } else if (response.contains('माहित नाही') ||
          response.contains("don't know") ||
          response.contains('जानकारी नहीं') ||
          response.contains('अजून माहिती नाही')) {
        _awaitingSave = true;
        _pendingSaveTopic = text;
        _pendingAppName = null;
      }
    }

    final aiMsg =
        ChatMessage(text: response, isUser: false, createdAt: DateTime.now());
    await DatabaseService.instance.saveChatMessage(aiMsg);
    setState(() {
      _messages.add(aiMsg);
      _isProcessing = false;
    });
    _scrollToBottom();
    await _tts.speak(response);
  }

  // ---------------------------------------------------------------
  // File upload — saves entire file as knowledge
  // ---------------------------------------------------------------
  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md'],
    );
    if (result == null) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final fileName =
        result.files.single.name.replaceAll(RegExp(r'\.[^.]+$'), '');

    await _ai.saveNewKnowledge(fileName, content, null);

    final response = _langCode == 'marathi'
        ? '📄 "$fileName" file ची सगळी माहिती save झाली!\n'
          'आता या file बद्दल विचारा.'
        : _langCode == 'hindi'
            ? '📄 "$fileName" file की जानकारी save हो गई! अब पूछें।'
            : '📄 "$fileName" saved! You can now ask me about it.';

    final aiMsg =
        ChatMessage(text: response, isUser: false, createdAt: DateTime.now());
    await DatabaseService.instance.saveChatMessage(aiMsg);
    setState(() => _messages.add(aiMsg));
    _scrollToBottom();
    await _tts.speak(response);
  }

  bool _isScreenReadCommand(String text) {
    final t = text.toLowerCase();
    return t.contains('screen vach') ||
        t.contains('screen read') ||
        t.contains('read screen') ||
        t.contains('screen पाह') ||
        t.contains('screen वाच') ||
        t.contains('स्क्रीन पढ़') ||
        t.contains('screen dekh') ||
        t.contains('open screen');
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
          if (text.isNotEmpty) _processInput(text);
        },
        localeId: _stt.localeFor(_langCode),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Code Magic Chat',
                style: TextStyle(color: Colors.white, fontSize: 17)),
            if (_teachMode)
              const Text('📚 शिकवा Mode चालू आहे',
                  style: TextStyle(
                      color: Color(0xFF3CE1C3),
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Teach Mode toggle button
          GestureDetector(
            onTap: () {
              setState(() => _teachMode = !_teachMode);
              final msg = _teachMode
                  ? (_langCode == 'marathi'
                      ? '📚 शिकवा Mode चालू! माहिती टाका — मी शिकतो.'
                      : '📚 Teach Mode ON!')
                  : (_langCode == 'marathi'
                      ? '✅ शिकवा Mode बंद. Normal chat.'
                      : '✅ Teach Mode OFF.');
              _tts.speak(msg);
              final aiMsg = ChatMessage(
                  text: _teachMode
                      ? (_langCode == 'marathi'
                          ? '📚 शिकवा Mode चालू!\n\n'
                            'आता तुम्ही Chat मध्ये जे माहिती लिहाल ते मी आपोआप save करेन.\n\n'
                            '✍️ उदाहरणे:\n'
                            '• "बुलिश कँडल म्हणजे हिरवी कँडल असते, किंमत वर जाते"\n'
                            '• "RSI 70 च्या वर गेला म्हणजे overbought"\n'
                            '• "BGMI मध्ये shotgun जवळून वापरावा"\n\n'
                            'लिहा! मी save करतो आणि trading analysis मध्ये वापरतो. 🤖'
                          : '📚 Teach Mode ON! Type any info and I\'ll save it.')
                      : (_langCode == 'marathi'
                          ? '✅ शिकवा Mode बंद. Normal chat चालू.'
                          : '✅ Teach Mode OFF.'),
                  isUser: false,
                  createdAt: DateTime.now());
              DatabaseService.instance.saveChatMessage(aiMsg);
              setState(() => _messages.add(aiMsg));
              _scrollToBottom();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _teachMode
                    ? const Color(0xFF3CE1C3)
                    : const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _teachMode
                      ? const Color(0xFF3CE1C3)
                      : const Color(0xFF6C3CE1),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _teachMode ? Icons.school : Icons.school_outlined,
                    color: _teachMode
                        ? const Color(0xFF0D0D1A)
                        : const Color(0xFF6C3CE1),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _langCode == 'marathi' ? 'शिकवा' : 'Teach',
                    style: TextStyle(
                      color: _teachMode
                          ? const Color(0xFF0D0D1A)
                          : const Color(0xFF6C3CE1),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
            onPressed: () async {
              await DatabaseService.instance.clearChat();
              setState(() => _messages.clear());
            },
            icon:
                const Icon(Icons.delete_outline, color: Colors.white54),
          ),
        ],
      ),
      body: Column(
        children: [
          // Teach Mode banner
          if (_teachMode) _buildTeachBanner(),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) =>
                        ChatBubble(message: _messages[i]),
                  ),
          ),
          if (_isProcessing) _buildTypingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildTeachBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0D2E28),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.school, color: Color(0xFF3CE1C3), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _langCode == 'marathi'
                  ? 'शिकवा Mode: तुम्ही लिहाल ती माहिती आपोआप save होईल आणि trading मध्ये वापरली जाईल'
                  : 'Teach Mode: Every message will be saved as knowledge for trading analysis',
              style: const TextStyle(
                  color: Color(0xFF3CE1C3),
                  fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome,
              size: 60,
              color: const Color(0xFF9B59F5).withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            _langCode == 'marathi'
                ? 'बोला किंवा टाइप करा\n\nTip: "शिकवा" button दाबा\nMarathi मध्ये माहिती save करायला'
                : _langCode == 'hindi'
                    ? 'बोलें या टाइप करें\n\nTip: "Teach" button दबाएं\nजानकारी save करने के लिए'
                    : 'Speak or type to start\n\nTip: Tap "Teach" to save knowledge',
            style: const TextStyle(
                color: Colors.white38, fontSize: 15, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [_dot(0), _dot(200), _dot(400)]),
          ),
        ],
      ),
    );
  }

  Widget _dot(int delay) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFF9B59F5),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF1A1A2E),
      child: Row(
        children: [
          IconButton(
            onPressed: _uploadFile,
            icon: const Icon(Icons.upload_file, color: Color(0xFF9B59F5)),
            tooltip: 'Upload text file',
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: _teachMode
                    ? (_langCode == 'marathi'
                        ? 'Marathi मध्ये माहिती लिहा... (auto save होईल)'
                        : 'Type info to save...')
                    : (_langCode == 'marathi'
                        ? 'बोला किंवा टाइप करा...'
                        : _langCode == 'hindi'
                            ? 'टाइप करें...'
                            : 'Type a message...'),
                hintStyle: TextStyle(
                  color: _teachMode
                      ? const Color(0xFF3CE1C3).withOpacity(0.6)
                      : Colors.white38,
                ),
                filled: true,
                fillColor: _teachMode
                    ? const Color(0xFF0D2E28)
                    : const Color(0xFF0D0D1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: _teachMode
                      ? const BorderSide(
                          color: Color(0xFF3CE1C3), width: 1)
                      : BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: _teachMode
                      ? const BorderSide(
                          color: Color(0xFF3CE1C3), width: 1)
                      : BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleMic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening
                    ? const Color(0xFF3CE1C3)
                    : const Color(0xFF6C3CE1),
              ),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              final text = _controller.text.trim();
              _controller.clear();
              _processInput(text);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _teachMode
                    ? const Color(0xFF3CE1C3)
                    : const Color(0xFF6C3CE1),
              ),
              child: Icon(
                _teachMode ? Icons.save : Icons.send,
                color: _teachMode
                    ? const Color(0xFF0D0D1A)
                    : Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
