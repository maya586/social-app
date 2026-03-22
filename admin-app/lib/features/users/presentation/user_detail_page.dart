import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../shared/widgets/glass_container.dart';
import '../data/users_repository.dart';

class UserDetailPage extends ConsumerStatefulWidget {
  final String userId;

  const UserDetailPage({super.key, required this.userId});

  @override
  ConsumerState<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends ConsumerState<UserDetailPage> {
  String? _expandedConversationId;
  int _messagePage = 1;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userDetailProvider(widget.userId));
    final chatsAsync = ref.watch(userChatsProvider(widget.userId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AdminTheme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                userAsync.when(
                  data: (user) => _buildContent(context, user, chatsAsync),
                  loading: () => _buildLoadingState(),
                  error: (error, _) => _buildErrorState(context, error),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            backgroundColor: AdminTheme.surfaceColor.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '用户详情',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, User user, AsyncValue<UserChatsResult> chatsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserCard(context, user),
        const SizedBox(height: 24),
        chatsAsync.when(
          data: (chats) => _buildChatsContent(context, user, chats),
          loading: () => _buildStatsLoading(),
          error: (error, _) => _buildChatsError(context, error),
        ),
      ],
    );
  }

  Widget _buildUserCard(BuildContext context, User user) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserAvatar(user),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.displayName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBadge(user.status),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.phone, '手机号', user.phone),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.calendar_today,
                  '注册时间',
                  _formatDateTime(user.createdAt),
                ),
                if (user.lastLoginAt != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.login,
                    '最后登录',
                    _formatDateTime(user.lastLoginAt!),
                  ),
                ],
              ],
            ),
          ),
          _buildActionButtons(context, user),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(User user) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: AdminTheme.primaryGradient,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: AdminTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: user.avatarUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: Image.network(
                user.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildDefaultAvatar(user),
              ),
            )
          : _buildDefaultAvatar(user),
    );
  }

  Widget _buildDefaultAvatar(User user) {
    return Center(
      child: Text(
        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final (color, text) = switch (status) {
      'active' => (AdminTheme.successColor, '正常'),
      'inactive' => (AdminTheme.warningColor, '禁用'),
      'banned' => (AdminTheme.errorColor, '封禁'),
      _ => (AdminTheme.textTertiary, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AdminTheme.textTertiary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: AdminTheme.textTertiary),
        ),
        Text(
          value,
          style: const TextStyle(color: AdminTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, User user) {
    final isActive = user.status == 'active';
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => _toggleUserStatus(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? AdminTheme.errorColor : AdminTheme.successColor,
          ),
          icon: Icon(isActive ? Icons.block : Icons.check_circle, size: 18),
          label: Text(isActive ? '禁用用户' : '启用用户'),
        ),
      ],
    );
  }

  Widget _buildChatsContent(BuildContext context, User user, UserChatsResult chats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatsCards(context, chats.stats),
        const SizedBox(height: 24),
        _buildConversationsSection(context, chats.conversations),
      ],
    );
  }

  Widget _buildStatsCards(BuildContext context, UserChatStats stats) {
    final cards = [
      _StatItem(
        title: '发送消息',
        value: stats.sentMessages.toString(),
        icon: Icons.send,
        color: AdminTheme.primaryColor,
      ),
      _StatItem(
        title: '接收消息',
        value: stats.receivedMessages.toString(),
        icon: Icons.inbox,
        color: AdminTheme.infoColor,
      ),
      _StatItem(
        title: '会话数',
        value: stats.conversations.toString(),
        icon: Icons.chat,
        color: AdminTheme.warningColor,
      ),
      _StatItem(
        title: '好友数',
        value: stats.friends.toString(),
        icon: Icons.people,
        color: AdminTheme.successColor,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 800 ? 4 : 2;
        final cardWidth = (constraints.maxWidth - (16 * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards.map((card) {
            return SizedBox(
              width: cardWidth,
              child: GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: card.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
                      ),
                      child: Icon(card.icon, color: card.color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.value,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            card.title,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildConversationsSection(BuildContext context, List<Conversation> conversations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '会话列表',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        if (conversations.isEmpty)
          _buildEmptyConversations()
        else
          ...conversations.map((conv) => _buildConversationItem(context, conv)),
      ],
    );
  }

  Widget _buildEmptyConversations() {
    return GlassContainer(
      padding: const EdgeInsets.all(32),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: AdminTheme.textTertiary),
            SizedBox(height: 12),
            Text('该用户暂无会话', style: TextStyle(color: AdminTheme.textTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationItem(BuildContext context, Conversation conversation) {
    final isExpanded = _expandedConversationId == conversation.id;

    return Column(
      children: [
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AdminTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Icon(
                        conversation.type == 'private' ? Icons.person : Icons.group,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conversation.displayName,
                          style: const TextStyle(
                            color: AdminTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          conversation.lastMessage ?? '暂无消息',
                          style: const TextStyle(color: AdminTheme.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AdminTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
                    ),
                    child: Text(
                      '${conversation.messageCount} 条',
                      style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _toggleConversation(conversation.id),
                    icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
                    label: Text(isExpanded ? '收起' : '查看消息'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primaryColor.withValues(alpha: 0.2),
                      foregroundColor: AdminTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(color: AdminTheme.glassBorder),
                const SizedBox(height: 16),
                _buildMessageList(conversation.id),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMessageList(String conversationId) {
    final messagesAsync = ref.watch(
      conversationMessagesProvider(
        ConversationMessagesParams(conversationId: conversationId, page: _messagePage),
      ),
    );

    return messagesAsync.when(
      data: (result) => _buildMessagesContent(result, conversationId),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AdminTheme.primaryColor),
        ),
      ),
      error: (error, _) => Center(
        child: Column(
          children: [
            Text('加载失败: $error', style: const TextStyle(color: AdminTheme.errorColor)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(conversationMessagesProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesContent(MessageListResult result, String conversationId) {
    if (result.messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('暂无消息记录', style: TextStyle(color: AdminTheme.textTertiary)),
        ),
      );
    }

    return Column(
      children: [
        ...result.messages.map((msg) => _buildMessageItem(msg)),
        if (result.totalPages > 1) ...[
          const SizedBox(height: 12),
          _buildMessagePagination(result, conversationId),
        ],
      ],
    );
  }

  Widget _buildMessageItem(Message message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AdminTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(
                _getMessageIcon(message.type),
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminTheme.infoColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        message.type,
                        style: const TextStyle(color: AdminTheme.infoColor, fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(message.createdAt),
                      style: const TextStyle(color: AdminTheme.textTertiary, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message.content ?? _getTypePlaceholder(message.type),
                  style: const TextStyle(color: AdminTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagePagination(MessageListResult result, String conversationId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: _messagePage > 1
              ? () => setState(() => _messagePage--)
              : null,
          icon: const Icon(Icons.chevron_left, size: 18),
          label: const Text('上一页'),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AdminTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AdminTheme.borderRadiusSmall),
          ),
          child: Text(
            '$_messagePage / ${result.totalPages}',
            style: const TextStyle(color: AdminTheme.textSecondary),
          ),
        ),
        TextButton.icon(
          onPressed: _messagePage < result.totalPages
              ? () => setState(() => _messagePage++)
              : null,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: const Text('下一页'),
        ),
      ],
    );
  }

  Widget _buildStatsLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: CircularProgressIndicator(color: AdminTheme.primaryColor),
      ),
    );
  }

  Widget _buildChatsError(BuildContext context, Object error) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AdminTheme.errorColor),
          const SizedBox(height: 12),
          Text('加载聊天数据失败', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(error.toString(), style: const TextStyle(color: AdminTheme.textTertiary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(userChatsProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AdminTheme.primaryColor),
            SizedBox(height: 16),
            Text('加载中...', style: TextStyle(color: AdminTheme.textTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return GlassContainer(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AdminTheme.errorColor),
          const SizedBox(height: 16),
          Text('加载失败', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(error.toString(), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(userDetailProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  void _toggleConversation(String conversationId) {
    setState(() {
      if (_expandedConversationId == conversationId) {
        _expandedConversationId = null;
      } else {
        _expandedConversationId = conversationId;
        _messagePage = 1;
      }
    });
  }

  Future<void> _toggleUserStatus(User user) async {
    final newStatus = user.status == 'active' ? 'inactive' : 'active';
    final confirmed = await _showConfirmDialog(
      context,
      newStatus == 'inactive' ? '禁用用户' : '启用用户',
      newStatus == 'inactive'
          ? '确定要禁用用户 ${user.displayName} 吗？禁用后该用户将无法登录。'
          : '确定要启用用户 ${user.displayName} 吗？',
    );

    if (confirmed == true) {
      try {
        await ref.read(usersRepositoryProvider).updateUserStatus(user.id, newStatus);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newStatus == 'inactive' ? '用户已禁用' : '用户已启用'),
              backgroundColor: AdminTheme.successColor,
            ),
          );
          ref.invalidate(userDetailProvider(widget.userId));
          ref.invalidate(usersListProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('操作失败: $e'),
              backgroundColor: AdminTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<bool?> _showConfirmDialog(BuildContext context, String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  IconData _getMessageIcon(String type) {
    return switch (type) {
      'text' => Icons.message,
      'image' => Icons.image,
      'voice' => Icons.mic,
      'video' => Icons.videocam,
      'file' => Icons.attach_file,
      _ => Icons.chat_bubble,
    };
  }

  String _getTypePlaceholder(String type) {
    return switch (type) {
      'image' => '[图片]',
      'voice' => '[语音]',
      'video' => '[视频]',
      'file' => '[文件]',
      _ => '[消息]',
    };
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}