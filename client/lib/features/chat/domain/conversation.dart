class Conversation {
  final String id;
  final String type;
  final String? name;
  final String? avatarUrl;
  final String? ownerId;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
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
    this.createdAt,
    this.lastMessage,
    this.lastSenderName,
    this.unreadCount = 0,
  });
  
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'private',
      name: json['name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      ownerId: json['owner_id']?.toString(),
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}