class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String type;
  final String? content;
  final String? mediaUrl;
  final int? duration;
  final String status;
  final DateTime? createdAt;
  
  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.content,
    this.mediaUrl,
    this.duration,
    required this.status,
    this.createdAt,
  });
  
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      content: json['content']?.toString(),
      mediaUrl: json['media_url']?.toString(),
      duration: json['duration'] is int ? json['duration'] : null,
      status: json['status']?.toString() ?? 'sent',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}