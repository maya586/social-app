class Contact {
  final String id;
  final String userId;
  final String contactId;
  final String? remark;
  final String status;
  final DateTime createdAt;
  
  Contact({
    required this.id,
    required this.userId,
    required this.contactId,
    this.remark,
    required this.status,
    required this.createdAt,
  });
  
  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      userId: json['user_id'],
      contactId: json['contact_id'],
      remark: json['remark'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}