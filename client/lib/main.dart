import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_provider.dart';
import 'features/auth/data/auth_repository.dart';
import 'core/services/network_permission_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _isChecking = true;
  bool _hasNetworkPermission = false;
  bool _permissionDialogShown = false;
  late AuthNotifier _authNotifier;
  
  @override
  void initState() {
    super.initState();
    _authNotifier = AuthNotifier(AuthRepository());
    _checkNetworkAndAuth();
  }
  
  Future<void> _checkNetworkAndAuth() async {
    final networkService = NetworkPermissionService();
    _hasNetworkPermission = await networkService.checkAndRequestPermission();
    
    if (!_hasNetworkPermission) {
      setState(() {
        _isChecking = false;
      });
      return;
    }
    
    final isAuthenticated = await _authNotifier.checkAuth();
    
    setState(() {
      _isChecking = false;
    });
    
    if (isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(routerProvider.notifier).goHome();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => _authNotifier),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: '社交应用',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: _buildHome(),
      ),
    );
  }
  
  Widget _buildHome() {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryColor),
              const SizedBox(height: 24),
              Text('正在检测网络...', style: TextStyle(color: Colors.white.withOpacity(0.8))),
            ],
          ),
        ),
      );
    }
    
    if (!_hasNetworkPermission) {
      return _buildNetworkPermissionScreen();
    }
    
    return buildRouter(ref);
  }
  
  Widget _buildNetworkPermissionScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_permissionDialogShown && mounted) {
        _showNetworkPermissionDialog();
      }
    });
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 64, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              '网络访问受限',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '请授权防火墙权限',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showNetworkPermissionDialog() {
    _permissionDialogShown = true;
    
    showDialog(
      context: navigatorKey.currentContext ?? context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Row(
          children: [
            Icon(Icons.security, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('防火墙授权', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '应用需要网络权限才能使用以下功能：',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 12),
            Text(
              '• 发送和接收消息\n• 语音/视频通话\n• 查看好友在线状态',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            SizedBox(height: 16),
            Text(
              '点击"授权"将自动添加防火墙规则（需要管理员权限）',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _permissionDialogShown = false;
            },
            child: const Text('稍后再说', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              Navigator.pop(context);
              
              final networkService = NetworkPermissionService();
              final result = await networkService.requestFirewallPermission();
              
              if (result.success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.message)),
                );
                setState(() {
                  _hasNetworkPermission = true;
                });
                _checkNetworkAndAuth();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: Colors.red,
                  ),
                );
                _permissionDialogShown = false;
              }
            },
            child: const Text('授权'),
          ),
        ],
      ),
    );
  }
}