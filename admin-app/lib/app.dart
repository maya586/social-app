import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/admin_theme.dart';
import 'core/state/admin_auth_provider.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/users/presentation/users_page.dart';
import 'features/monitor/presentation/monitor_page.dart';
import 'features/settings/presentation/settings_page.dart';

class AdminApp extends ConsumerStatefulWidget {
  const AdminApp({super.key});

  @override
  ConsumerState<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends ConsumerState<AdminApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminAuthProvider.notifier).checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(adminAuthProvider);

    return MaterialApp(
      title: '管理后台',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.darkTheme,
      home: _buildHome(authState),
      routes: {
        '/login': (context) => const AdminLoginPage(),
        '/dashboard': (context) => const MainShell(),
      },
    );
  }

  Widget _buildHome(AdminAuthState authState) {
    if (authState.isLoading) {
      return const _SplashScreen();
    }

    if (authState.isAuthenticated) {
      return const MainShell();
    }

    return const AdminLoginPage();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AdminTheme.backgroundGradient),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AdminTheme.primaryColor),
              SizedBox(height: 24),
              Text(
                '加载中...',
                style: TextStyle(
                  color: AdminTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  final _pages = const [
    DashboardPage(),
    UsersPage(),
    MonitorPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AdminTheme.backgroundGradient),
        child: Row(
          children: [
            _buildNavigationRail(),
            Expanded(child: _pages[_selectedIndex]),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRail() {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: AdminTheme.surfaceColor.withValues(alpha: 0.5),
        border: const Border(
          right: BorderSide(color: AdminTheme.glassBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildLogo(),
          const SizedBox(height: 32),
          Expanded(
            child: _buildNavItems(),
          ),
          _buildLogoutButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: AdminTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
    );
  }

  Widget _buildNavItems() {
    final items = [
      (Icons.dashboard_outlined, Icons.dashboard, '仪表盘'),
      (Icons.people_outline, Icons.people, '用户'),
      (Icons.monitor_heart_outlined, Icons.monitor_heart, '监控'),
      (Icons.settings_outlined, Icons.settings, '设置'),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final (unselected, selected, _) = entry.value;
        final isSelected = _selectedIndex == index;

        return _NavItem(
          icon: isSelected ? selected : unselected,
          isSelected: isSelected,
          onTap: () => setState(() => _selectedIndex = index),
        );
      }).toList(),
    );
  }

  Widget _buildLogoutButton() {
    return _NavItem(
      icon: Icons.logout,
      isSelected: false,
      onTap: () async {
        await ref.read(adminAuthProvider.notifier).logout();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      },
      isLogout: true,
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isLogout;

  const _NavItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? AdminTheme.primaryColor.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isLogout
                ? AdminTheme.errorColor
                : isSelected
                    ? AdminTheme.primaryColor
                    : AdminTheme.textSecondary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderPage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AdminTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AdminTheme.textSecondary,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '功能开发中...',
            style: TextStyle(
              color: AdminTheme.textTertiary.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}