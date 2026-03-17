import '../../../core/network/api_client.dart';
import '../domain/message.dart';
import '../domain/conversation.dart';

class ChatRepository {
  final _api = ApiClient().dio;
  
  Future<List<Conversation>> getConversations({int limit = 20, String? cursor}) async {
    String url = '/conversations?limit=$limit';
    if (cursor != null) {
      url += '&cursor=$cursor';
    }
    
    final response = await _api.get(url);
    final data = response.data['data'] ?? response.data;
    
    if (data is List) {
      return data.map((json) => Conversation.fromJson(json)).toList();
    }
    
    final List<dynamic> conversations = data['conversations'] ?? [];
    return conversations.map((json) => Conversation.fromJson(json)).toList();
  }
  
  Future<List<Message>> getMessages(String conversationId, {String? cursor, int limit = 20}) async {
    String url = '/messages/conversation/$conversationId?limit=$limit';
    if (cursor != null) {
      url += '&cursor=$cursor';
    }
    
    final response = await _api.get(url);
    final data = response.data['data'] ?? response.data;
    
    if (data is List) {
      return data.map((json) => Message.fromJson(json)).toList();
    }
    
    final List<dynamic> messages = data['messages'] ?? [];
    return messages.map((json) => Message.fromJson(json)).toList();
  }
  
  Future<Message> sendMessage({
    required String conversationId,
    required String type,
    String? content,
    String? mediaUrl,
    int? duration,
  }) async {
    final response = await _api.post('/messages', data: {
      'conversation_id': conversationId,
      'type': type,
      'content': content,
      'media_url': mediaUrl,
      'duration': duration,
    });
    final data = response.data['data'] ?? response.data;
    return Message.fromJson(data);
  }
  
  Future<void> recallMessage(String messageId) async {
    await _api.delete('/messages/$messageId');
  }
  
  Future<Conversation> createPrivateConversation(String contactId) async {
    if (contactId.isEmpty) {
      throw Exception('联系人ID不能为空');
    }
    
    final response = await _api.post('/conversations', data: {
      'type': 'private',
      'contact_id': contactId,
    });
    final data = response.data['data'] ?? response.data;
    return Conversation.fromJson(data);
  }
}