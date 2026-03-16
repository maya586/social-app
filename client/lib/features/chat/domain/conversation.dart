class Conversation {
  final String id;
  final String type;
  final String? name;
  final String? avatarUrl;
  final String? ownerId;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  String? lastMessage;
  String? lastSenderName;
  int unreadCount;
  
  Conversation({
    required this.id,
    required this.type,
    this.name,
    this.avatarUrl,
    this.ownerId,
    this.lastMessageAt,
    required this.createdAt,
    this.lastMessage,
    this.lastSenderName,
    this.unreadCount = 0,
  });
  
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      type: json['type'],
      name: json['name'],
      avatarUrl: json['avatar_url'],
      ownerId: json['owner_id'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}