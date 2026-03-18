import 'dart:async';
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
      if (event == 'user:status') {
        final data = message['data'] as Map<String, dynamic>?;
        if (data != null) {
          final userId = data['user_id'] as String?;
          final isOnline = data['is_online'] as bool?;
          if (userId != null && isOnline != null) {
            print('Online status update: $userId -> $isOnline');
            state = {...state, userId: isOnline};
          }
        }
      }
    });
  }
  
  bool isOnline(String? userId) {
    if (userId == null) return false;
    return state[userId] ?? false;
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}