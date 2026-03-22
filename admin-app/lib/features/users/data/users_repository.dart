import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/admin_api_client.dart';

class User {
  final String id;
  final String phone;
  final String? nickname;
  final String? avatarUrl;
  final String status;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const User({
    required this.id,
    required this.phone,
    this.nickname,
    this.avatarUrl,
    required this.status,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
    );
  }

  String get statusText => status == 'active' ? '正常' : '禁用';
  String get displayName => nickname ?? '用户$id'.substring(0, 8);
}

class UserListResult {
  final List<User> users;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const UserListResult({
    required this.users,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory UserListResult.fromJson(Map<String, dynamic> json) {
    return UserListResult(
      users: (json['users'] as List<dynamic>?)
              ?.map((e) => User.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      totalPages: json['total_page'] as int? ?? 0,
    );
  }
}

class UserChatStats {
  final int sentMessages;
  final int receivedMessages;
  final int conversations;
  final int friends;
  final int storageBytes;

  const UserChatStats({
    required this.sentMessages,
    required this.receivedMessages,
    required this.conversations,
    required this.friends,
    required this.storageBytes,
  });

  factory UserChatStats.fromJson(Map<String, dynamic> json) {
    return UserChatStats(
      sentMessages: json['sent_messages'] as int? ?? 0,
      receivedMessages: json['received_messages'] as int? ?? 0,
      conversations: json['conversations'] as int? ?? 0,
      friends: json['friends'] as int? ?? 0,
      storageBytes: json['storage_bytes'] as int? ?? 0,
    );
  }
}

class Conversation {
  final String id;
  final String type;
  final String? otherUserNickname;
  final String? lastMessage;
  final int messageCount;

  const Conversation({
    required this.id,
    required this.type,
    this.otherUserNickname,
    this.lastMessage,
    required this.messageCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'private',
      otherUserNickname: json['other_user_nickname'] as String?,
      lastMessage: json['last_message'] as String?,
      messageCount: json['message_count'] as int? ?? 0,
    );
  }

  String get displayName => otherUserNickname ?? '会话';
}

class Message {
  final String id;
  final String type;
  final String? content;
  final String senderId;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.type,
    this.content,
    required this.senderId,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String?,
      senderId: json['sender_id'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class MessageListResult {
  final List<Message> messages;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const MessageListResult({
    required this.messages,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory MessageListResult.fromJson(Map<String, dynamic> json) {
    return MessageListResult(
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => Message.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 50,
      totalPages: json['total_page'] as int? ?? 0,
    );
  }
}

class UserChatsResult {
  final UserChatStats stats;
  final List<Conversation> conversations;

  const UserChatsResult({
    required this.stats,
    required this.conversations,
  });

  factory UserChatsResult.fromJson(Map<String, dynamic> json) {
    return UserChatsResult(
      stats: UserChatStats.fromJson(
          json['stats'] as Map<String, dynamic>? ?? {}),
      conversations: (json['conversations'] as List<dynamic>?)
              ?.map((e) => Conversation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class UsersRepository {
  final AdminApiClient _apiClient;

  UsersRepository({AdminApiClient? apiClient})
      : _apiClient = apiClient ?? AdminApiClient();

  Future<UserListResult> getUsers({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (keyword != null && keyword.isNotEmpty) {
      queryParams['keyword'] = keyword;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await _apiClient.dio.get(
      '/admin/users',
      queryParameters: queryParams,
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return UserListResult.fromJson(data);
  }

  Future<User> getUser(String userId) async {
    final response = await _apiClient.dio.get('/admin/users/$userId');
    final data = response.data['data'] as Map<String, dynamic>;
    return User.fromJson(data);
  }

  Future<String> updateUserStatus(String userId, String status) async {
    final response = await _apiClient.dio.put(
      '/admin/users/$userId/status',
      data: {'status': status},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return data['status'] as String;
  }

  Future<UserChatsResult> getUserChats(String userId) async {
    final response = await _apiClient.dio.get('/admin/users/$userId/chats');
    final data = response.data['data'] as Map<String, dynamic>;
    return UserChatsResult.fromJson(data);
  }

  Future<MessageListResult> getConversationMessages(
    String conversationId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _apiClient.dio.get(
      '/admin/conversations/$conversationId/messages',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return MessageListResult.fromJson(data);
  }
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository();
});

final usersListProvider =
    FutureProvider.family<UserListResult, UserListParams>((ref, params) async {
  final repository = ref.watch(usersRepositoryProvider);
  return repository.getUsers(
    page: params.page,
    pageSize: params.pageSize,
    keyword: params.keyword,
    status: params.status,
  );
});

class UserListParams {
  final int page;
  final int pageSize;
  final String? keyword;
  final String? status;

  const UserListParams({
    this.page = 1,
    this.pageSize = 20,
    this.keyword,
    this.status,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserListParams &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          pageSize == other.pageSize &&
          keyword == other.keyword &&
          status == other.status;

  @override
  int get hashCode =>
      page.hashCode ^ pageSize.hashCode ^ keyword.hashCode ^ status.hashCode;
}

final userDetailProvider =
    FutureProvider.family<User, String>((ref, userId) async {
  final repository = ref.watch(usersRepositoryProvider);
  return repository.getUser(userId);
});

final userChatsProvider =
    FutureProvider.family<UserChatsResult, String>((ref, userId) async {
  final repository = ref.watch(usersRepositoryProvider);
  return repository.getUserChats(userId);
});

final conversationMessagesProvider =
    FutureProvider.family<MessageListResult, ConversationMessagesParams>(
        (ref, params) async {
  final repository = ref.watch(usersRepositoryProvider);
  return repository.getConversationMessages(
    params.conversationId,
    page: params.page,
  );
});

class ConversationMessagesParams {
  final String conversationId;
  final int page;

  const ConversationMessagesParams({
    required this.conversationId,
    this.page = 1,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationMessagesParams &&
          runtimeType == other.runtimeType &&
          conversationId == other.conversationId &&
          page == other.page;

  @override
  int get hashCode => conversationId.hashCode ^ page.hashCode;
}