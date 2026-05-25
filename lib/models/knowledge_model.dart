class KnowledgeItem {
  final int? id;
  final String topic;
  final String content;
  final String? appName;
  final DateTime createdAt;

  KnowledgeItem({
    this.id,
    required this.topic,
    required this.content,
    this.appName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'topic': topic,
      'content': content,
      'app_name': appName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory KnowledgeItem.fromMap(Map<String, dynamic> map) {
    return KnowledgeItem(
      id: map['id'],
      topic: map['topic'],
      content: map['content'],
      appName: map['app_name'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class ChatMessage {
  final int? id;
  final String text;
  final bool isUser;
  final DateTime createdAt;

  ChatMessage({
    this.id,
    required this.text,
    required this.isUser,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'is_user': isUser ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      text: map['text'],
      isUser: map['is_user'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
