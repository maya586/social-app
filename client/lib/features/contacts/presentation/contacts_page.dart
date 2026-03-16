import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/contacts_repository.dart';
import '../domain/contact.dart';

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
            onPressed: () {
              _showAddContactDialog();
            },
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
                hintText: '搜索联系人',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onChanged: (value) {
                // TODO: Implement search
              },
            ),
          ),
          Expanded(
            child: contactsAsync.when(
              data: (contacts) {
                if (contacts.isEmpty) {
                  return const Center(child: Text('暂无联系人'));
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
  
  void _showAddContactDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加联系人'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '用户ID',
              hintText: '输入要添加的用户ID',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final contactId = controller.text.trim();
                if (contactId.isNotEmpty) {
                  try {
                    await ref.read(contactsRepositoryProvider).addContact(contactId);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('好友请求已发送')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('添加失败: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;
  
  const _ContactTile({required this.contact});
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(contact.remark ?? contact.contactId.substring(0, 2)),
      ),
      title: Text(contact.remark ?? contact.contactId),
      subtitle: Text(_getStatusText(contact.status)),
      onTap: () {
        // TODO: Navigate to chat
      },
    );
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