import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_router.dart';
import '../../../core/network/websocket_service.dart';
import '../data/chat_provider.dart';
import '../domain/conversation.dart';

class ConversationListPage extends ConsumerStatefulWidget {
  const ConversationListPage({super.key});
  
  @override
  ConsumerState<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends ConsumerState<ConversationListPage> {
  int _currentIndex = 0;
  
  @override
  void initState() {
    super.initState();
    WebSocketService().connect();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _ConversationList(),
          _ContactsTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
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
    );
  }
}

class _ConversationList extends ConsumerWidget {
  const _ConversationList();
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(conversationsProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: conversationsAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(child: Text('暂无会话'));
          }
          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              return _ConversationTile(conversation: conversations[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败: $error')),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final Conversation conversation;
  
  const _ConversationTile({required this.conversation});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(conversation.name ?? conversation.id.substring(0, 2)),
      ),
      title: Text(conversation.name ?? '私聊'),
      subtitle: Text(
        conversation.lastMessage ?? '暂无消息',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: conversation.unreadCount > 0
          ? Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            )
          : null,
      onTap: () {
        ref.read(routerProvider.notifier).goChat(conversation.id);
      },
    );
  }
}

class _ContactsTab extends ConsumerWidget {
  const _ContactsTab();
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('联系人')),
      body: const Center(child: Text('联系人列表')),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('我')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: const Text('个人信息'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('退出登录'),
            onTap: () async {
              await ref.read(authStateProvider.notifier).logout();
              ref.read(routerProvider.notifier).goLogin();
            },
          ),
        ],
      ),
    );
  }
}