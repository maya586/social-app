import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/websocket_service.dart';

final onlineStatusProvider = StateNotifierProvider<OnlineStatusNotifier, Map<String, bool>>((ref) {
  return OnlineStatusNotifier();
});

class OnlineStatusNotifier extends StateNotifier<Map<String, bool>> {
  StreamSubscription? _subscription;
  
  OnlineStatusNotifier() : super({}) {
    _listenToStatus();
  }
  
  void _listenToStatus() {
    _subscription = WebSocketService().messages.listen((message) {
      final event = message['event'] as String?;
      
      if (event == 'online_users') {
        final rawData = message['data'];
        List<dynamic>? usersList;
        
        if (rawData is List) {
          usersList = rawData;
        } else if (rawData is String) {
          try {
            usersList = jsonDecode(rawData) as List;
          } catch (e) {
            print('Failed to parse online_users data: $e');
          }
        }
        
        if (usersList != null) {
          final newState = Map<String, bool>.from(state);
          for (final user in usersList) {
            final userId = user['user_id'] as String?;
            final isOnline = user['is_online'] as bool?;
            if (userId != null && isOnline != null) {
              newState[userId] = isOnline;
            }
          }
          state = newState;
          print('Online users list received: ${usersList.length} users online');
        }
      } else if (event == 'user:status') {
        final data = message['data'] as Map<String, dynamic>?;
        if (data != null) {
          final userId = data['user_id'] as String?;
          final isOnline = data['is_online'] as bool?;
          final source = data['source'] as String?;
          if (userId != null && isOnline != null) {
            if (source != 'init') {
              print('Online status update: $userId -> $isOnline');
            }
            state = {...state, userId: isOnline};
          }
        }
      }
    });
  }
  
  bool isOnline(String? userId) {
    if (userId == null) return false;
    final result = state[userId] ?? false;
    return result;
  }
  
  void setUserOnline(String userId, bool isOnline) {
    state = {...state, userId: isOnline};
  }
  
  void clearStatus(String userId) {
    final newState = Map<String, bool>.from(state);
    newState.remove(userId);
    state = newState;
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}