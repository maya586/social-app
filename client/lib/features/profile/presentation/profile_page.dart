import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_router.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_provider.dart';
import '../../auth/domain/user.dart';

final userProfileProvider = FutureProvider<User?>((ref) async {
  final api = ApiClient().dio;
  try {
    final response = await api.get('/users/me');
    final data = response.data['data'];
    return User.fromJson(data);
  } catch (e) {
    return null;
  }
});

class ProfileTabPage extends ConsumerStatefulWidget {
  const ProfileTabPage({super.key});
  
  @override
  ConsumerState<ProfileTabPage> createState() => _ProfileTabPageState();
}

class _ProfileTabPageState extends ConsumerState<ProfileTabPage> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('我'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: () => _showQRCode(context),
            tooltip: '我的二维码',
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) => _buildContent(context, user),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }
  
  Widget _buildContent(BuildContext context, User? user) {
    return ListView(
      children: [
        _buildProfileHeader(context, user),
        const SizedBox(height: 8),
        _buildAccountSection(context, user),
        const SizedBox(height: 8),
        _buildSettingsSection(context),
        const SizedBox(height: 8),
        _buildOtherSection(context),
        const SizedBox(height: 24),
        _buildLogoutButton(context),
        const SizedBox(height: 24),
        _buildVersionInfo(),
      ],
    );
  }
  
  Widget _buildProfileHeader(BuildContext context, User? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => _showEditProfile(context, user),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Theme.of(context).colorScheme.primary,
              backgroundImage: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                  ? NetworkImage(user.avatarUrl!) as ImageProvider
                  : null,
              child: user?.avatarUrl == null || user!.avatarUrl!.isEmpty
                  ? Text(
                      user?.nickname?.substring(0, 1) ?? '?',
                      style: const TextStyle(fontSize: 28, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.nickname ?? '未设置昵称',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '账号: ${user?.phone ?? ''}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${user?.id?.substring(0, 8) ?? ''}...',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAccountSection(BuildContext context, User? user) {
    return _SettingsSection(
      title: '账号',
      children: [
        _SettingsTile(
          icon: Icons.person_outline,
          title: '个人信息',
          subtitle: '修改昵称、头像等',
          onTap: () => _showEditProfile(context, user),
        ),
        _SettingsTile(
          icon: Icons.lock_outline,
          title: '账号与安全',
          subtitle: '密码、手机号管理',
          onTap: () => _showSecuritySettings(context),
        ),
        _SettingsTile(
          icon: Icons.phone_android,
          title: '设备管理',
          subtitle: '查看登录设备',
          onTap: () => _showDeviceManagement(context),
        ),
      ],
    );
  }
  
  Widget _buildSettingsSection(BuildContext context) {
    return _SettingsSection(
      title: '设置',
      children: [
        _SettingsSwitch(
          icon: Icons.notifications_outlined,
          title: '消息通知',
          subtitle: '接收新消息提醒',
          value: _notificationsEnabled,
          onChanged: (value) => setState(() => _notificationsEnabled = value),
        ),
        _SettingsSwitch(
          icon: Icons.volume_up_outlined,
          title: '声音',
          subtitle: '消息提示音',
          value: _soundEnabled,
          onChanged: (value) => setState(() => _soundEnabled = value),
        ),
        _SettingsSwitch(
          icon: Icons.vibration,
          title: '震动',
          subtitle: '消息震动提醒',
          value: _vibrationEnabled,
          onChanged: (value) => setState(() => _vibrationEnabled = value),
        ),
        _SettingsTile(
          icon: Icons.chat_bubble_outline,
          title: '聊天设置',
          subtitle: '字体大小、聊天背景',
          onTap: () => _showChatSettings(context),
        ),
        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: '隐私设置',
          subtitle: '黑名单、朋友权限',
          onTap: () => _showPrivacySettings(context),
        ),
      ],
    );
  }
  
  Widget _buildOtherSection(BuildContext context) {
    return _SettingsSection(
      title: '其他',
      children: [
        _SettingsTile(
          icon: Icons.help_outline,
          title: '帮助与反馈',
          onTap: () => _showHelp(context),
        ),
        _SettingsTile(
          icon: Icons.info_outline,
          title: '关于',
          subtitle: '版本 1.0.0',
          onTap: () => _showAbout(context),
        ),
        _SettingsTile(
          icon: Icons.storage_outlined,
          title: '存储空间',
          subtitle: '管理本地缓存',
          onTap: () => _showStorageManagement(context),
        ),
      ],
    );
  }
  
  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () => _confirmLogout(context),
        child: const Text('退出登录'),
      ),
    );
  }
  
  Widget _buildVersionInfo() {
    return Center(
      child: Column(
        children: [
          Text('社交应用 v1.0.0', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 4),
          Text('© 2026 Social App', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
        ],
      ),
    );
  }
  
  void _showQRCode(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('我的二维码', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: Icon(Icons.qr_code_2, size: 150, color: Colors.grey)),
            ),
            const SizedBox(height: 16),
            Text('扫一扫上面的二维码，加我好友', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
  
  void _showEditProfile(BuildContext context, User? user) {
    final nicknameController = TextEditingController(text: user?.nickname ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('编辑资料', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nicknameController,
              decoration: const InputDecoration(labelText: '昵称', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('取消'))),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final api = ApiClient().dio;
                        await api.put('/users/me', data: {'nickname': nicknameController.text});
                        if (context.mounted) {
                          Navigator.pop(context);
                          ref.invalidate(userProfileProvider);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('修改成功')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('修改失败: $e')));
                        }
                      }
                    },
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  void _showSecuritySettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('账号与安全', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('修改密码'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showChangePassword(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('更换手机号'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('功能开发中')));
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showChangePassword(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldPasswordController, decoration: const InputDecoration(labelText: '原密码'), obscureText: true),
            TextField(controller: newPasswordController, decoration: const InputDecoration(labelText: '新密码'), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('功能开发中')));
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  void _showDeviceManagement(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('设备管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.computer),
              title: Text('Windows 客户端'),
              subtitle: Text('当前设备 · 在线'),
              trailing: Icon(Icons.check_circle, color: Colors.green),
            ),
            const Divider(),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已清除其他设备登录状态')));
              },
              child: const Text('清除其他设备登录状态', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showChatSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('聊天设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const ListTile(title: Text('字体大小'), trailing: Text('标准')),
            const ListTile(title: Text('聊天背景'), trailing: Icon(Icons.chevron_right)),
          ],
        ),
      ),
    );
  }
  
  void _showPrivacySettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('隐私设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('黑名单'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('黑名单为空')));
              },
            ),
            const ListTile(
              leading: Icon(Icons.people_outline),
              title: Text('加好友验证'),
              subtitle: Text('需要验证'),
              trailing: Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('帮助与反馈', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('意见反馈'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showFeedbackDialog(context),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showFeedbackDialog(BuildContext context) {
    Navigator.pop(context);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('意见反馈'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: '请描述您的问题或建议', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('感谢您的反馈')));
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }
  
  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '社交应用',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 Social App Team',
      children: const [SizedBox(height: 16), Text('一款简洁高效的跨平台社交应用')],
    );
  }
  
  void _showStorageManagement(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('存储空间', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const ListTile(title: Text('聊天记录'), subtitle: Text('12.5 MB')),
            const ListTile(title: Text('图片缓存'), subtitle: Text('8.2 MB')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('缓存已清除')));
              },
              child: const Text('清除所有缓存'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authStateProvider.notifier).logout();
              ref.read(routerProvider.notifier).goLogin();
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  
  const _SettingsSection({required this.title, required this.children});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        Container(color: Theme.of(context).colorScheme.surface, child: Column(children: children)),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  
  const _SettingsTile({required this.icon, required this.title, this.subtitle, this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(color: Colors.grey[500], fontSize: 12)) : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  
  const _SettingsSwitch({required this.icon, required this.title, this.subtitle, required this.value, this.onChanged});
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(color: Colors.grey[500], fontSize: 12)) : null,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}