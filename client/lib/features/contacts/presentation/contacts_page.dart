import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_router.dart';
import '../data/contacts_repository.dart';
import '../domain/contact.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/chat_provider.dart';

final contactsRepositoryProvider = Provider((ref) => ContactsRepository());

final contactsProvider = FutureProvider<List<Contact>>((ref) async {
  return ref.read(contactsRepositoryProvider).getContacts();
});

final pendingRequestsProvider = FutureProvider<List<Contact>>((ref) async {
  return ref.read(contactsRepositoryProvider).getPendingRequests();
});

class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key});
  
  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {
  final _searchController = TextEditingController();
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);
    final pendingAsync = ref.watch(pendingRequestsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('联系人'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddContactDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索联系人或手机号',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _searchUserByPhone(value);
                }
              },
            ),
          ),
          Expanded(
            child: pendingAsync.when(
              data: (pending) {
                return contactsAsync.when(
                  data: (contacts) {
                    return _buildContactList(context, pending, contacts);
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(child: Text('加载失败: $error')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('加载失败: $error')),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContactList(BuildContext context, List<Contact> pending, List<Contact> contacts) {
    return ListView(
      children: [
        if (pending.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange.shade50,
            child: Row(
              children: [
                Icon(Icons.person_add_alt_1, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  '好友请求 (${pending.length})',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...pending.map((contact) => _PendingRequestTile(
            contact: contact,
            onAccept: () => _acceptRequest(contact.id),
            onReject: () => _rejectRequest(contact.id),
          )),
          const Divider(height: 24),
        ],
        if (contacts.isEmpty && pending.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('暂无联系人\n点击右上角添加', textAlign: TextAlign.center)),
          )
        else if (contacts.isEmpty && pending.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('暂无已添加的联系人', textAlign: TextAlign.center)),
          )
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '我的联系人 (${contacts.length})',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...contacts.map((contact) => _ContactTile(
            contact: contact,
            onStartChat: () => _startChat(context, contact),
          )),
        ],
      ],
    );
  }
  
  Future<void> _acceptRequest(String requestId) async {
    final success = await ref.read(contactsRepositoryProvider).acceptContact(requestId);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已添加好友')),
        );
        ref.invalidate(contactsProvider);
        ref.invalidate(pendingRequestsProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('接受失败，请重试')),
        );
      }
    }
  }
  
  Future<void> _rejectRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('拒绝好友请求'),
        content: const Text('确定要拒绝这个好友请求吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('拒绝', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final success = await ref.read(contactsRepositoryProvider).rejectContact(requestId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已拒绝好友请求')),
          );
          ref.invalidate(pendingRequestsProvider);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('操作失败，请重试')),
          );
        }
      }
    }
  }
  
  void _searchUserByPhone(String phone) async {
    try {
      final user = await ref.read(contactsRepositoryProvider).searchUserByPhone(phone);
      if (mounted) {
        _showSearchResultDialog(user);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('未找到用户: $e')),
        );
      }
    }
  }
  
  void _showSearchResultDialog(Map<String, dynamic> user) {
    final String contactId = user['id'].toString();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('找到用户'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('昵称: ${user['nickname'] ?? '未设置'}'),
            Text('手机: ${user['phone'] ?? ''}'),
            Text('ID: ${contactId.substring(0, 8)}...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _addContact(contactId);
            },
            child: const Text('添加好友'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _addContact(String contactId) async {
    final result = await ref.read(contactsRepositoryProvider).addContact(contactId);
    if (mounted) {
      if (result == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('好友请求已发送')),
        );
        ref.invalidate(contactsProvider);
      } else if (result == 'already_exists') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该联系人已存在')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
      }
    }
  }
  
  void _showAddContactDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加联系人'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '手机号',
                  hintText: '输入对方手机号搜索',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final phone = controller.text.trim();
                if (phone.isNotEmpty) {
                  Navigator.pop(context);
                  _searchUserByPhone(phone);
                }
              },
              child: const Text('搜索'),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _startChat(BuildContext context, Contact contact) async {
    if (contact.contactId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('联系人信息无效')),
      );
      return;
    }
    
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final conversation = await chatRepo.createPrivateConversation(contact.contactId);
      if (conversation.id.isEmpty) {
        throw Exception('会话创建失败');
      }
      ref.read(routerProvider.notifier).goChat(conversation.id);
      ref.invalidate(conversationsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建会话失败: $e')),
        );
      }
    }
  }
}

class _PendingRequestTile extends StatelessWidget {
  final Contact contact;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  
  const _PendingRequestTile({
    required this.contact,
    required this.onAccept,
    required this.onReject,
  });
  
  @override
  Widget build(BuildContext context) {
    final displayName = contact.getDisplayName();
    final subtitle = contact.contactUser?.phone ?? contact.userId?.substring(0, 8) ?? '未知';
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.orange.shade100,
        child: Text(displayName.isNotEmpty ? displayName.substring(0, 1) : '?'),
      ),
      title: Text(displayName),
      subtitle: Text('请求添加好友 · $subtitle'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: onAccept,
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('接受'),
          ),
          TextButton(
            onPressed: onReject,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('拒绝'),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;
  final VoidCallback? onStartChat;
  
  const _ContactTile({
    required this.contact,
    this.onStartChat,
  });
  
  @override
  Widget build(BuildContext context) {
    final displayName = contact.getDisplayName();
    final subtitle = contact.contactUser?.phone ?? contact.contactId.substring(0, 8);
    
    return ListTile(
      leading: CircleAvatar(
        child: Text(displayName.isNotEmpty ? displayName.substring(0, 1) : '?'),
      ),
      title: Text(displayName),
      subtitle: Text(subtitle),
      trailing: IconButton(
        icon: const Icon(Icons.chat),
        onPressed: onStartChat,
      ),
      onTap: onStartChat,
    );
  }
}