import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/websocket_service.dart';

class NewMessage {
  final String conversationId;
  final String? senderId;
  final String? senderName;
  final String? content;
  final String? type;
  final DateTime timestamp;
  
  NewMessage({
    required this.conversationId,
    this.senderId,
    this.senderName,
    this.content,
    this.type,
    required this.timestamp,
  });
}

final messageNotificationProvider = StateNotifierProvider<MessageNotificationNotifier, List<NewMessage>>((ref) {
  return MessageNotificationNotifier();
});

class MessageNotificationNotifier extends StateNotifier<List<NewMessage>> {
  StreamSubscription? _subscription;
  String? _currentConversationId;
  
  MessageNotificationNotifier() : super([]) {
    _listenToMessages();
  }
  
  void _listenToMessages() {
    _subscription = WebSocketService().messages.listen((message) {
      final event = message['event'] as String?;
      print('MessageNotification received: $event');
      if (event == 'message:new') {
        final data = message['data'] as Map<String, dynamic>?;
        if (data != null) {
          final msgConversationId = data['conversation_id']?.toString();
          final senderId = data['sender_id']?.toString();
          
          print('New message in conversation: $msgConversationId, sender: $senderId, current: $_currentConversationId');
          
          if (msgConversationId != null && msgConversationId != _currentConversationId) {
            final newMessage = NewMessage(
              conversationId: msgConversationId,
              senderId: senderId,
              senderName: data['sender_name'] as String?,
              content: data['content'] as String?,
              type: data['type'] as String?,
              timestamp: DateTime.now(),
            );
            state = [...state, newMessage];
            print('Message notification added, total: ${state.length}');
          }
        }
      }
    });
  }
  
  void setCurrentConversation(String? conversationId) {
    _currentConversationId = conversationId;
    if (conversationId != null) {
      state = state.where((msg) => msg.conversationId != conversationId).toList();
    }
  }
  
  void clearNotifications(String conversationId) {
    state = state.where((msg) => msg.conversationId != conversationId).toList();
  }
  
  void clearAll() {
    state = [];
  }
  
  int getUnreadCount(String conversationId) {
    return state.where((msg) => msg.conversationId == conversationId).length;
  }
  
  int get totalUnreadCount => state.length;
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}