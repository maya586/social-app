class User {
  final String id;
  final String phone;
  final String nickname;
  final String? avatarUrl;
  final String status;
  final DateTime createdAt;
  
  User({
    required this.id,
    required this.phone,
    required this.nickname,
    this.avatarUrl,
    required this.status,
    required this.createdAt,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phone: json['phone'],
      nickname: json['nickname'],
      avatarUrl: json['avatar_url'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'nickname': nickname,
    'avatar_url': avatarUrl,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };
}