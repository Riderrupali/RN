import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/tts_service.dart';
import '../models/knowledge_model.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  List<KnowledgeItem> _items = [];
  final _searchController = TextEditingController();
  final _topicController = TextEditingController();
  final _contentController = TextEditingController();
  final _appController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String query = '']) async {
    final items = query.isEmpty
        ? await DatabaseService.instance.getAllKnowledge()
        : await DatabaseService.instance.searchKnowledge(query);
    setState(() => _items = items);
  }

  void _showAddDialog() {
    _topicController.clear();
    _contentController.clear();
    _appController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('माहिती Add करा 📚',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Marathi, Hindi किंवा English — कोणत्याही भाषेत लिहा',
                style: TextStyle(color: Color(0xFF3CE1C3), fontSize: 12),
              ),
              const SizedBox(height: 10),
              _field(_topicController,
                  'विषय / Topic\nउदा: Bullish Candle, BGMI Strategy'),
              const SizedBox(height: 10),
              _field(_appController,
                  'App चे नाव (optional)\nउदा: Zerodha, Free Fire'),
              const SizedBox(height: 10),
              _field(_contentController,
                  'माहिती / Information\nMarathi मध्ये लिहा — उदा: बुलिश कँडल म्हणजे हिरवी कँडल, किंमत वर जाते',
                  maxLines: 5),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C3CE1)),
            onPressed: () async {
              if (_topicController.text.isEmpty || _contentController.text.isEmpty) return;
              await DatabaseService.instance.saveKnowledge(KnowledgeItem(
                topic: _topicController.text,
                content: _contentController.text,
                appName: _appController.text.isEmpty ? null : _appController.text,
                createdAt: DateTime.now(),
              ));
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF0D0D1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Knowledge Base', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6C3CE1),
        onPressed: _showAddDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: _load,
              decoration: InputDecoration(
                hintText: 'Search knowledge...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      'No knowledge yet.\nTap + to add or teach via chat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _buildCard(_items[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(KnowledgeItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9B59F5).withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(item.topic,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.appName != null)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C3CE1).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(item.appName!,
                    style: const TextStyle(color: Color(0xFF9B59F5), fontSize: 11)),
              ),
            Text(
              item.content.length > 100
                  ? '${item.content.substring(0, 100)}...'
                  : item.content,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => TtsService.instance.speak(item.content),
              icon: const Icon(Icons.volume_up, color: Color(0xFF9B59F5), size: 20),
            ),
            IconButton(
              onPressed: () async {
                await DatabaseService.instance.deleteKnowledge(item.id!);
                _load();
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
