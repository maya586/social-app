import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/websocket_service.dart';
import '../core/router/app_router.dart';
import 'domain/call_state.dart';
import 'presentation/call_page.dart';

final callNotificationProvider = StateNotifierProvider<CallNotificationService, IncomingCall?>((ref) {
  return CallNotificationService(ref);
});

class IncomingCall {
  final String roomId;
  final String conversationId;
  final String callerId;
  final String callerName;
  final CallType callType;
  
  IncomingCall({
    required this.roomId,
    required this.conversationId,
    required this.callerId,
    required this.callerName,
    required this.callType,
  });
}

class CallNotificationService extends StateNotifier<IncomingCall?> {
  final Ref ref;
  StreamSubscription? _wsSubscription;
  
  CallNotificationService(this.ref) : super(null) {
    _init();
  }
  
  void _init() {
    _wsSubscription = WebSocketService().messages.listen(_handleMessage);
  }
  
  void _handleMessage(Map<String, dynamic> message) {
    final event = message['event'] as String?;
    
    if (event == 'call:incoming') {
      final data = message['data'] as Map<String, dynamic>?;
      if (data != null) {
        final callTypeStr = data['type'] as String? ?? 'audio';
        
        state = IncomingCall(
          roomId: data['room_id'] ?? '',
          conversationId: data['conversation_id'] ?? '',
          callerId: data['caller_id'] ?? '',
          callerName: data['caller_name'] ?? 'Unknown',
          callType: callTypeStr == 'video' ? CallType.video : CallType.audio,
        );
      }
    }
  }
  
  void acceptCall() {
    final call = state;
    if (call != null) {
      ref.read(routerProvider.notifier).goCall(call.conversationId, call.callType);
    }
    state = null;
  }
  
  void rejectCall() {
    WebSocketService().send({
      'event': 'call:reject',
      'data': {'room_id': state?.roomId},
    });
    state = null;
  }
  
  void clearCall() {
    state = null;
  }
  
  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}

class CallNotificationOverlay extends ConsumerWidget {
  final Widget child;
  
  const CallNotificationOverlay({super.key, required this.child});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingCall = ref.watch(callNotificationProvider);
    
    return Stack(
      children: [
        child,
        if (incomingCall != null)
          Positioned.fill(
            child: Material(
              color: Colors.black54,
              child: Center(
                child: IncomingCallDialog(
                  callerName: incomingCall.callerName,
                  callType: incomingCall.callType,
                  onAccept: () {
                    ref.read(callNotificationProvider.notifier).acceptCall();
                  },
                  onReject: () {
                    ref.read(callNotificationProvider.notifier).rejectCall();
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}