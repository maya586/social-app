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
            child: contactsAsync.when(
              data: (contacts) {
                if (contacts.isEmpty) {
                  return const Center(child: Text('暂无联系人\n点击右上角添加', textAlign: TextAlign.center));
                }
                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    return _ContactTile(contact: contacts[index]);
                  },
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
}

class _ContactTile extends ConsumerWidget {
  final Contact contact;
  
  const _ContactTile({required this.contact});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = contact.getDisplayName();
    final subtitle = contact.contactUser?.phone ?? contact.contactId.substring(0, 8);
    
    return ListTile(
      leading: CircleAvatar(
        child: Text(displayName.isNotEmpty ? displayName.substring(0, 1) : '?'),
      ),
      title: Text(displayName),
      subtitle: Text('$subtitle · ${_getStatusText(contact.status)}'),
      trailing: contact.status == 'accepted' 
          ? IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () => _startChat(context, ref),
            )
          : null,
      onTap: () {
        if (contact.status == 'accepted') {
          _startChat(context, ref);
        }
      },
    );
  }
  
  Future<void> _startChat(BuildContext context, WidgetRef ref) async {
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final conversation = await chatRepo.createPrivateConversation(contact.contactId);
      ref.read(routerProvider.notifier).goChat(conversation.id);
      ref.invalidate(conversationsProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建会话失败: $e')),
      );
    }
  }
  
  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '等待验证';
      case 'accepted':
        return '已添加';
      case 'blocked':
        return '已屏蔽';
      default:
        return status;
    }
  }
}