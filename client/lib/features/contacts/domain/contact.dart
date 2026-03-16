class ContactUser {
  final String id;
  final String phone;
  final String nickname;
  final String? avatarUrl;
  
  ContactUser({
    required this.id,
    required this.phone,
    required this.nickname,
    this.avatarUrl,
  });
  
  factory ContactUser.fromJson(Map<String, dynamic> json) {
    return ContactUser(
      id: json['id'],
      phone: json['phone'],
      nickname: json['nickname'],
      avatarUrl: json['avatar_url'],
    );
  }
}

class Contact {
  final String id;
  final String userId;
  final String contactId;
  final String? remark;
  final String status;
  final DateTime createdAt;
  final ContactUser? contactUser;
  
  Contact({
    required this.id,
    required this.userId,
    required this.contactId,
    this.remark,
    required this.status,
    required this.createdAt,
    this.contactUser,
  });
  
  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      userId: json['user_id'],
      contactId: json['contact_id'],
      remark: json['remark'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      contactUser: json['contact_user'] != null 
          ? ContactUser.fromJson(json['contact_user']) 
          : null,
    );
  }
  
  String getDisplayName() {
    if (remark != null && remark!.isNotEmpty) {
      return remark!;
    }
    if (contactUser != null) {
      return contactUser!.nickname;
    }
    return contactId.substring(0, 8);
  }
}