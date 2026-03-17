class ContactUser {
  final String id;
  final String? phone;
  final String? nickname;
  final String? avatarUrl;
  
  ContactUser({
    required this.id,
    this.phone,
    this.nickname,
    this.avatarUrl,
  });
  
  factory ContactUser.fromJson(Map<String, dynamic> json) {
    return ContactUser(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString(),
      nickname: json['nickname']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}

class Contact {
  final String id;
  final String? userId;
  final String contactId;
  final String? remark;
  final String status;
  final DateTime? createdAt;
  final ContactUser? contactUser;
  
  Contact({
    required this.id,
    this.userId,
    required this.contactId,
    this.remark,
    required this.status,
    this.createdAt,
    this.contactUser,
  });
  
  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      contactId: json['contact_id']?.toString() ?? '',
      remark: json['remark']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      contactUser: json['contact_user'] != null 
          ? ContactUser.fromJson(json['contact_user']) 
          : null,
    );
  }
  
  String getDisplayName() {
    if (remark != null && remark!.isNotEmpty) {
      return remark!;
    }
    if (contactUser != null && contactUser!.nickname != null) {
      return contactUser!.nickname!;
    }
    if (contactId.isNotEmpty) {
      return contactId.substring(0, 8);
    }
    return '未知用户';
  }
}