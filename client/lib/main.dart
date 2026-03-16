import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'features/auth/data/auth_provider.dart';
import 'features/auth/data/auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final authNotifier = AuthNotifier(AuthRepository());
  final isAuthenticated = await authNotifier.checkAuth();
  
  runApp(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => authNotifier),
      ],
      child: MyApp(isAuthenticated: isAuthenticated),
    ),
  );
}

class MyApp extends ConsumerWidget {
  final bool isAuthenticated;
  
  const MyApp({super.key, required this.isAuthenticated});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isAuthenticated) {
      ref.read(routerProvider.notifier).goHome();
    }
    
    return MaterialApp(
      title: '社交应用',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
        ),
      ),
      home: buildRouter(ref),
    );
  }
}