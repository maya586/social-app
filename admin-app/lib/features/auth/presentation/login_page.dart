import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../core/state/admin_auth_provider.dart';
import '../../../shared/widgets/glass_container.dart';

class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(adminAuthProvider.notifier).login(
          username: _usernameController.text,
          password: _passwordController.text,
        );

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(adminAuthProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AdminTheme.backgroundGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    SizedBox(height: size.height * 0.05),
                    _buildGlassForm(authState),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.3),
                Colors.white.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
          ),
          child: const Icon(Icons.admin_panel_settings, size: 50, color: Colors.white),
        ),
        const SizedBox(height: 24),
        const Text(
          '管理后台',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '社交应用管理系统',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.8),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassForm(AdminAuthState authState) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '管理员登录',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '请输入您的凭据',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildUsernameField(),
            const SizedBox(height: 16),
            _buildPasswordField(),
            const SizedBox(height: 24),
            _buildLoginButton(authState),
            if (authState.error != null) _buildErrorMessage(authState.error!),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      style: const TextStyle(color: AdminTheme.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        labelText: '用户名',
        prefixIcon: const Icon(Icons.person_outline, color: AdminTheme.textSecondary),
        labelStyle: const TextStyle(color: AdminTheme.textSecondary),
        filled: true,
        fillColor: AdminTheme.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
          borderSide: const BorderSide(color: AdminTheme.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
          borderSide: const BorderSide(color: AdminTheme.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
          borderSide: const BorderSide(color: AdminTheme.primaryColor, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return '请输入用户名';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: AdminTheme.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        labelText: '密码',
        prefixIcon: const Icon(Icons.lock_outline, color: AdminTheme.textSecondary),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AdminTheme.textSecondary,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        labelStyle: const TextStyle(color: AdminTheme.textSecondary),
        filled: true,
        fillColor: AdminTheme.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
          borderSide: const BorderSide(color: AdminTheme.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
          borderSide: const BorderSide(color: AdminTheme.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
          borderSide: const BorderSide(color: AdminTheme.primaryColor, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return '请输入密码';
        if (value.length < 6) return '密码至少6位';
        return null;
      },
    );
  }

  Widget _buildLoginButton(AdminAuthState authState) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: AdminTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
        boxShadow: [
          BoxShadow(
            color: AdminTheme.primaryColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: authState.isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
          ),
        ),
        child: authState.isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                '登录',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
        border: Border.all(color: AdminTheme.errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AdminTheme.errorColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: AdminTheme.errorColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}