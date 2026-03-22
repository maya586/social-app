import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../shared/widgets/glass_container.dart';
import '../data/users_repository.dart';
import 'user_detail_page.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final _searchController = TextEditingController();
  int _currentPage = 1;
  String? _statusFilter;
  String? _keyword;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _currentPage = 1;
    });
    ref.invalidate(usersListProvider);
  }

  void _search() {
    setState(() {
      _keyword = _searchController.text.trim();
      _currentPage = 1;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _keyword = null;
      _currentPage = 1;
    });
  }

  void _onStatusFilterChanged(String? status) {
    setState(() {
      _statusFilter = status;
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final params = UserListParams(
      page: _currentPage,
      pageSize: 20,
      keyword: _keyword,
      status: _statusFilter,
    );
    final usersAsync = ref.watch(usersListProvider(params));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildFilters(context),
              const SizedBox(height: 16),
              usersAsync.when(
                data: (result) => _buildContent(context, result),
                loading: () => _buildLoadingState(),
                error: (error, _) => _buildErrorState(context, error),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Text(
      '用户管理',
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索用户（昵称/手机号）',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _keyword != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.search, size: 18),
            label: const Text('搜索'),
          ),
          const SizedBox(width: 16),
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AdminTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
              border: Border.all(color: AdminTheme.glassBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                isExpanded: true,
                hint: const Text('全部状态', style: TextStyle(fontSize: 14)),
                items: const [
                  DropdownMenuItem(value: null, child: Text('全部状态')),
                  DropdownMenuItem(value: 'active', child: Text('正常')),
                  DropdownMenuItem(value: 'inactive', child: Text('禁用')),
                  DropdownMenuItem(value: 'banned', child: Text('封禁')),
                ],
                onChanged: _onStatusFilterChanged,
                dropdownColor: AdminTheme.cardColor,
                style: const TextStyle(color: AdminTheme.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, UserListResult result) {
    if (result.users.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        _buildUserList(context, result.users),
        const SizedBox(height: 16),
        _buildPagination(context, result),
      ],
    );
  }

  Widget _buildUserList(BuildContext context, List<User> users) {
    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildTableHeader(context),
          const Divider(height: 1, color: AdminTheme.glassBorder),
          ...users.map((user) => _buildUserRow(context, user)),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          const SizedBox(width: 60, child: Text('头像', style: TextStyle(fontWeight: FontWeight.w600))),
          const Expanded(flex: 2, child: Text('昵称', style: TextStyle(fontWeight: FontWeight.w600))),
          const Expanded(flex: 2, child: Text('手机号', style: TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 80, child: Text('状态', style: TextStyle(fontWeight: FontWeight.w600))),
          const Expanded(child: Text('注册时间', style: TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 100, child: Text('操作', style: TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildUserRow(BuildContext context, User user) {
    return InkWell(
      onTap: () => _navigateToDetail(context, user.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AdminTheme.glassBorder, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: _buildAvatar(user),
            ),
            Expanded(
              flex: 2,
              child: Text(
                user.displayName,
                style: const TextStyle(color: AdminTheme.textPrimary),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _maskPhone(user.phone),
                style: const TextStyle(color: AdminTheme.textSecondary),
              ),
            ),
            SizedBox(
              width: 80,
              child: _buildStatusBadge(user.status),
            ),
            Expanded(
              child: Text(
                _formatDate(user.createdAt),
                style: const TextStyle(color: AdminTheme.textTertiary),
              ),
            ),
            SizedBox(
              width: 100,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusButton(user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(User user) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: AdminTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: user.avatarUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
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
          fontSize: 16,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AdminTheme.borderRadiusSmall),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildStatusButton(User user) {
    final isActive = user.status == 'active';
    return TextButton(
      onPressed: () => _toggleUserStatus(user),
      style: TextButton.styleFrom(
        foregroundColor: isActive ? AdminTheme.errorColor : AdminTheme.successColor,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(60, 32),
      ),
      child: Text(isActive ? '禁用' : '启用'),
    );
  }

  Widget _buildPagination(BuildContext context, UserListResult result) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 1
                ? () => setState(() => _currentPage--)
                : null,
            icon: const Icon(Icons.chevron_left),
            color: AdminTheme.textSecondary,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AdminTheme.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AdminTheme.borderRadiusSmall),
            ),
            child: Text(
              '$_currentPage / ${result.totalPages}',
              style: const TextStyle(color: AdminTheme.primaryColor),
            ),
          ),
          IconButton(
            onPressed: _currentPage < result.totalPages
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_right),
            color: AdminTheme.textSecondary,
          ),
          const SizedBox(width: 16),
          Text(
            '共 ${result.total} 条',
            style: const TextStyle(color: AdminTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 64, color: AdminTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            _keyword != null || _statusFilter != null
                ? '未找到匹配的用户'
                : '暂无用户数据',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AdminTheme.textTertiary,
                ),
          ),
          if (_keyword != null || _statusFilter != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _keyword = null;
                  _statusFilter = null;
                  _currentPage = 1;
                });
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('清除筛选'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return GlassContainer(
      padding: const EdgeInsets.all(48),
      child: const Center(
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
          Text(
            '加载失败',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(BuildContext context, String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserDetailPage(userId: userId),
      ),
    );
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

  String _maskPhone(String phone) {
    if (phone.length >= 7) {
      return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
    }
    return phone;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}