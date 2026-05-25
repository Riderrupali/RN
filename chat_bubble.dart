import 'package:flutter/material.dart';
import '../models/knowledge_model.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF6C3CE1), Color(0xFF9B59F5)],
                )
              : null,
          color: isUser ? null : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser
              ? null
              : Border.all(color: const Color(0xFF9B59F5).withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 14, color: Color(0xFF9B59F5)),
                    SizedBox(width: 4),
                    Text(
                      'Code Magic',
                      style: TextStyle(
                          color: Color(0xFF9B59F5),
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.white70,
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
