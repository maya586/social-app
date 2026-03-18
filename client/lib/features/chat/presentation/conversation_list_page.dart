import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_router.dart';
import '../../../core/network/websocket_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/online_status_provider.dart';
import '../../../core/state/message_notification_provider.dart';
import '../data/chat_provider.dart';
import '../domain/conversation.dart';
import '../../auth/data/auth_provider.dart';
import '../../contacts/presentation/contacts_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../call/presentation/call_page.dart';

class ConversationListPage extends ConsumerStatefulWidget {
  const ConversationListPage({super.key});
  
  @override
  ConsumerState<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends ConsumerState<ConversationListPage> {
  int _currentIndex = 0;
  StreamSubscription? _wsSubscription;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WebSocketService().connect();
      _listenForEvents();
    });
  }
  
  void _listenForEvents() {
    _wsSubscription = WebSocketService().messages.listen((message) {
      final event = message['event'] as String?;
      print('ConversationList received: $event');
      
      if (event == 'call:offer') {
        final rawData = message['data'];
        print('call:offer raw data: $rawData');
        Map<String, dynamic>? data;
        
        if (rawData is Map<String, dynamic>) {
          data = rawData;
        } else if (rawData is String) {
          try {
            data = jsonDecode(rawData) as Map<String, dynamic>;
          } catch (e) {
            print('Failed to parse call:offer data: $e');
          }
        }
        
        if (data != null && mounted) {
          print('Showing incoming call dialog with data: $data');
          _showIncomingCallDialog(data);
        }
      }
      
      if (event == 'message:new') {
        ref.read(conversationsProvider.notifier).refresh();
      }
    });
  }
  
  void _showIncomingCallDialog(Map<String, dynamic> data) {
    final roomId = data['room_id'] as String?;
    final isVideo = data['is_video'] as bool? ?? false;
    final callerName = data['caller_name'] as String? ?? '用户';
    
    if (roomId == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('来电', style: TextStyle(color: Colors.white)),
        content: Text('$callerName 邀请您${isVideo ? '视频' : '语音'}通话', 
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('拒绝', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CallPage(
                    roomId: roomId,
                    isVideo: isVideo,
                    isCaller: false,
                    offerData: data,
                  ),
                ),
              );
            },
            child: const Text('接听'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            _ConversationList(),
            ContactsPage(),
            ProfileTabPage(),
          ],
        ),
        bottomNavigationBar: GlassContainer(
          borderRadius: 0,
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.chat), label: '消息'),
              NavigationDestination(icon: Icon(Icons.contacts), label: '联系人'),
              NavigationDestination(icon: Icon(Icons.person), label: '我'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationList extends ConsumerWidget {
  const _ConversationList();
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('消息', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              ref.read(conversationsProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: conversationsAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: GlassContainer(
                padding: const EdgeInsets.all(32),
                child: const Text('暂无会话', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              return _ConversationTile(conversation: conversations[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (error, stack) => Center(
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Text('加载失败: $error', style: const TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final Conversation conversation;
  
  const _ConversationTile({required this.conversation});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineStatus = ref.watch(onlineStatusProvider);
    final messageNotifications = ref.watch(messageNotificationProvider);
    final isOtherOnline = conversation.type == 'private' && 
        conversation.otherUserId != null && 
        (onlineStatus[conversation.otherUserId] ?? false);
    final pendingCount = messageNotifications.where((m) => m.conversationId == conversation.id).length;
    final totalUnread = conversation.unreadCount + pendingCount;
    
    final displayName = conversation.displayName;
    final displayInitial = displayName.isNotEmpty ? displayName.substring(0, 1) : '?';
    final lastMessageText = conversation.lastMessage ?? '暂无消息';
    final lastSenderPrefix = conversation.lastSenderName != null ? '${conversation.lastSenderName}: ' : '';
    
    return GlassContainer(
      margin: const EdgeInsets.symmetric(vertical: 6),
      borderRadius: 16,
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.8),
              backgroundImage: conversation.displayAvatar.isNotEmpty 
                  ? NetworkImage('http://localhost:8080${conversation.displayAvatar}')
                  : null,
              child: conversation.displayAvatar.isEmpty
                  ? Text(
                      displayInitial,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    )
                  : null,
            ),
            if (isOtherOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isOtherOnline)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '在线',
                  style: TextStyle(color: Colors.green, fontSize: 10),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '$lastSenderPrefix$lastMessageText',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: totalUnread > 0 ? Colors.white : Colors.white.withOpacity(0.7),
            fontWeight: totalUnread > 0 ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        trailing: totalUnread > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.accentColor, AppTheme.warningColor]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalUnread',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              )
            : Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
        onTap: () {
          ref.read(messageNotificationProvider.notifier).setCurrentConversation(conversation.id);
          ref.read(routerProvider.notifier).goChat(conversation.id);
        },
      ),
    );
  }
}