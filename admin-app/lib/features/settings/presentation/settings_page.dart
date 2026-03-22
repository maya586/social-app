import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../shared/widgets/glass_container.dart';
import '../data/settings_repository.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final configsAsync = ref.watch(configsProvider);

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
              configsAsync.when(
                data: (configs) => _buildContent(context, configs),
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
      '系统设置',
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildContent(BuildContext context, List<SystemConfig> configs) {
    if (configs.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: configs.map((config) => _buildConfigCard(context, config)).toList(),
    );
  }

  Widget _buildConfigCard(BuildContext context, SystemConfig config) {
    if (config.key == 'allow_registration') {
      return _buildRegistrationToggle(context, config);
    }
    return _buildReadOnlyConfig(context, config);
  }

  Widget _buildRegistrationToggle(BuildContext context, SystemConfig config) {
    final isEnabled = config.boolValue;
    final updateState = ref.watch(configUpdateProvider);
    final isUpdating = updateState.isLoading;

    return GlassContainer(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 16),
      child: SwitchListTile(
        title: const Text(
          '允许新用户注册',
          style: TextStyle(
            color: AdminTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          isEnabled ? '新用户可以注册账号' : '新用户无法注册账号',
          style: const TextStyle(
            color: AdminTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        value: isEnabled,
        onChanged: isUpdating ? null : (value) => _toggleRegistration(config, value),
        activeThumbColor: AdminTheme.successColor,
        activeTrackColor: AdminTheme.successColor.withValues(alpha: 0.4),
        inactiveThumbColor: AdminTheme.textTertiary,
        inactiveTrackColor: AdminTheme.surfaceColor,
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isEnabled
                ? AdminTheme.successColor.withValues(alpha: 0.2)
                : AdminTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
          ),
          child: Icon(
            Icons.person_add,
            color: isEnabled ? AdminTheme.successColor : AdminTheme.textTertiary,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyConfig(BuildContext context, SystemConfig config) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AdminTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: AdminTheme.textTertiary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.key,
                  style: const TextStyle(
                    color: AdminTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (config.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    config.description!,
                    style: const TextStyle(
                      color: AdminTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AdminTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AdminTheme.borderRadiusSmall),
            ),
            child: Text(
              config.value,
              style: const TextStyle(
                color: AdminTheme.textSecondary,
                fontSize: 14,
              ),
            ),
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
          const Icon(Icons.settings_outlined, size: 64, color: AdminTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            '暂无系统配置',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AdminTheme.textTertiary,
                ),
          ),
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
            onPressed: () => ref.invalidate(configsProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRegistration(SystemConfig config, bool newValue) async {
    final confirmed = await _showConfirmDialog(
      context,
      newValue ? '开启注册' : '关闭注册',
      newValue
          ? '确定要允许新用户注册吗？新用户将能够创建账号。'
          : '确定要禁止新用户注册吗？新用户将无法创建账号。',
    );

    if (confirmed == true) {
      final success = await ref
          .read(configUpdateProvider.notifier)
          .updateConfig(config.key, newValue.toString());

      if (mounted) {
        if (success) {
          ref.invalidate(configsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newValue ? '已开启新用户注册' : '已关闭新用户注册'),
              backgroundColor: AdminTheme.successColor,
            ),
          );
        } else {
          final error = ref.read(configUpdateProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('操作失败: ${error.error ?? "未知错误"}'),
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
        backgroundColor: AdminTheme.cardColor,
        title: Text(title, style: const TextStyle(color: AdminTheme.textPrimary)),
        content: Text(message, style: const TextStyle(color: AdminTheme.textSecondary)),
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
}