import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/online_status_provider.dart';
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('联系人', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
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
              style: const TextStyle(color: AppTheme.inputText, fontSize: 16, fontWeight: FontWeight.w500),
              decoration: AppTheme.glassInputDecoration(
                hintText: '搜索联系人或手机号',
                prefixIcon: const Icon(Icons.search, color: AppTheme.inputHint),
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
                  loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                  error: (error, stack) => Center(
                    child: GlassContainer(
                      padding: const EdgeInsets.all(24),
                      child: Text('加载失败: $error', style: const TextStyle(color: Colors.white)),
                    ),
                  ),
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
          ),
        ],
      ),
    );
  }
  
  Widget _buildContactList(BuildContext context, List<Contact> pending, List<Contact> contacts) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (pending.isNotEmpty) ...[
          GlassContainer(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: 16,
            child: Row(
              children: [
                Icon(Icons.person_add_alt_1, color: AppTheme.warningColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  '好友请求 (${pending.length})',
                  style: TextStyle(color: AppTheme.warningColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          ...pending.map((contact) => _PendingRequestTile(
            contact: contact,
            onAccept: () => _acceptRequest(contact.id),
            onReject: () => _rejectRequest(contact.id),
          )),
          const SizedBox(height: 16),
        ],
        if (contacts.isEmpty && pending.isEmpty)
          GlassContainer(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(32),
            child: const Text('暂无联系人\n点击右上角添加', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
          )
        else if (contacts.isEmpty && pending.isNotEmpty)
          GlassContainer(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(32),
            child: const Text('暂无已添加的联系人', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '我的联系人 (${contacts.length})',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500),
            ),
          ),
          ...contacts.map((contact) => _ContactTile(
            contact: contact,
            onStartChat: () => _startChat(context, contact),
            onClearChat: () => _clearChatForContact(contact),
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
  
  Future<void> _clearChatForContact(Contact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('清空聊天记录', style: TextStyle(color: Colors.white)),
        content: Text('确定要清空与 ${contact.getDisplayName()} 的聊天记录吗？', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final conversation = await chatRepo.createPrivateConversation(contact.contactId);
      
      if (conversation.id.isNotEmpty) {
        await chatRepo.clearConversation(conversation.id);
        ref.invalidate(conversationsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('聊天记录已清空')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清空失败: $e')),
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
    
    return GlassContainer(
      margin: const EdgeInsets.symmetric(vertical: 4),
      borderRadius: 16,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.warningColor.withOpacity(0.8),
          child: Text(
            displayName.isNotEmpty ? displayName.substring(0, 1) : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        title: Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '请求添加好友 · $subtitle',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: onAccept,
              style: TextButton.styleFrom(foregroundColor: AppTheme.successColor),
              child: const Text('接受'),
            ),
            TextButton(
              onPressed: onReject,
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
              child: const Text('拒绝'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends ConsumerWidget {
  final Contact contact;
  final VoidCallback? onStartChat;
  final VoidCallback? onClearChat;
  
  const _ContactTile({
    required this.contact,
    this.onStartChat,
    this.onClearChat,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = contact.getDisplayName();
    final subtitle = contact.contactUser?.phone ?? contact.contactId.substring(0, 8);
    final onlineStatus = ref.watch(onlineStatusProvider);
    final isOnline = onlineStatus[contact.contactId] ?? false;
    
    return GestureDetector(
      onSecondaryTapDown: (details) {
        _showContextMenu(context, details);
      },
      child: GlassContainer(
        margin: const EdgeInsets.symmetric(vertical: 4),
        borderRadius: 16,
        child: ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withOpacity(0.8),
                child: Text(
                  displayName.isNotEmpty ? displayName.substring(0, 1) : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          title: Row(
            children: [
              Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(
                isOnline ? '在线' : '离线',
                style: TextStyle(
                  color: isOnline ? Colors.green : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.7))),
          trailing: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.chat, color: Colors.white),
              onPressed: onStartChat,
            ),
          ),
          onTap: onStartChat,
        ),
      ),
    );
  }
  
  void _showContextMenu(BuildContext context, TapDownDetails details) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );
    
    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.delete_sweep, color: Colors.red),
              SizedBox(width: 8),
              Text('清空聊天记录'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'clear') {
        onClearChat?.call();
      }
    });
  }
}