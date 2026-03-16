import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/app_router.dart';
import '../../auth/data/auth_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    
    return Scaffold(
      appBar: AppBar(title: const Text('个人中心')),
      body: ListView(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            currentAccountPicture: CircleAvatar(
              child: Text(
                user?.nickname.substring(0, 1) ?? 'U',
                style: const TextStyle(fontSize: 32),
              ),
            ),
            accountName: Text(user?.nickname ?? '未登录'),
            accountEmail: Text(user?.phone ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('个人信息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to profile edit
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('账号安全'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to security settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('通知设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to notification settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('系统设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to system settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('关于'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: '社交应用',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 Social App',
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('退出登录', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('确认退出'),
                    content: const Text('确定要退出登录吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('退出'),
                      ),
                    ],
                  );
                },
              );
              
              if (confirmed == true) {
                await ref.read(authStateProvider.notifier).logout();
                ref.read(routerProvider.notifier).goLogin();
              }
            },
          ),
        ],
      ),
    );
  }
}