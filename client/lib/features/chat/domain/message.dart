class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String type;
  final String? content;
  final String? mediaUrl;
  final String status;
  final DateTime createdAt;
  
  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.content,
    this.mediaUrl,
    required this.status,
    required this.createdAt,
  });
  
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      type: json['type'],
      content: json['content'],
      mediaUrl: json['media_url'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}