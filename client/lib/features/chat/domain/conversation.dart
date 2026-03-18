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
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserAvatar;
  
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
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatar,
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
      lastMessage: json['last_message']?.toString(),
      lastSenderName: json['last_sender_name']?.toString(),
      unreadCount: json['unread_count'] ?? 0,
      otherUserId: json['other_user_id']?.toString(),
      otherUserName: json['other_user_name']?.toString(),
      otherUserAvatar: json['other_user_avatar']?.toString(),
    );
  }
  
  String get displayName {
    if (type == 'private') {
      return otherUserName ?? name ?? '私聊';
    }
    return name ?? '群聊';
  }
  
  String get displayAvatar {
    if (type == 'private') {
      return otherUserAvatar ?? avatarUrl ?? '';
    }
    return avatarUrl ?? '';
  }
}