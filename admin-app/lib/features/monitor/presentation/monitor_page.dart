import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../shared/widgets/glass_container.dart';
import '../data/monitor_repository.dart';

class MonitorPage extends ConsumerStatefulWidget {
  const MonitorPage({super.key});

  @override
  ConsumerState<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends ConsumerState<MonitorPage> {
  Timer? _refreshTimer;
  DateTime? _lastUpdate;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshData();
    });
  }

  void _refreshData() {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    ref.invalidate(monitorDataProvider);
    ref.read(monitorDataProvider.future).then((_) {
      if (mounted) {
        setState(() {
          _lastUpdate = DateTime.now();
          _isRefreshing = false;
        });
      }
    }).catchError((_) {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final monitorAsync = ref.watch(monitorDataProvider);

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
              monitorAsync.when(
                data: (data) => _buildContent(context, data),
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '系统监控',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              if (_lastUpdate != null)
                Text(
                  '最后更新: ${_formatTime(_lastUpdate!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isRefreshing
                ? AdminTheme.warningColor.withValues(alpha: 0.2)
                : AdminTheme.successColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AdminTheme.borderRadiusSmall),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isRefreshing ? Icons.sync : Icons.circle,
                size: 12,
                color: _isRefreshing
                    ? AdminTheme.warningColor
                    : AdminTheme.successColor,
              ),
              const SizedBox(width: 6),
              Text(
                _isRefreshing ? '刷新中...' : '实时监控',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _isRefreshing
                          ? AdminTheme.warningColor
                          : AdminTheme.successColor,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, MonitorData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildServerResourcesSection(context, data.server),
        const SizedBox(height: 24),
        _buildApiPerformanceSection(context, data.api),
        const SizedBox(height: 24),
        _buildRealtimeConnectionsSection(context, data.realtime),
      ],
    );
  }

  Widget _buildServerResourcesSection(BuildContext context, ServerStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '服务器资源', Icons.dns, AdminTheme.primaryColor),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth >= 900 ? 3 : 1;
            final cardWidth = crossAxisCount == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - (16 * (crossAxisCount - 1))) / crossAxisCount;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _buildGaugeCard(
                    context,
                    title: 'CPU 使用率',
                    value: stats.cpu,
                    color: _getResourceColor(stats.cpu),
                    icon: Icons.memory,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildGaugeCard(
                    context,
                    title: '内存使用率',
                    value: stats.memory,
                    color: _getResourceColor(stats.memory),
                    icon: Icons.storage,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildGaugeCard(
                    context,
                    title: '磁盘使用率',
                    value: stats.disk,
                    color: _getResourceColor(stats.disk),
                    icon: Icons.folder,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildGaugeCard(
    BuildContext context, {
    required String title,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _CircularGaugePainter(
                value: value,
                color: color,
                backgroundColor: AdminTheme.glassBackground,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${value.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                    ),
                    Text(
                      '使用中',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiPerformanceSection(BuildContext context, ApiStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'API 性能', Icons.api, AdminTheme.infoColor),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth >= 900 ? 3 : 1;
            final cardWidth = crossAxisCount == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - (16 * (crossAxisCount - 1))) / crossAxisCount;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _buildMetricCard(
                    context,
                    title: '请求/秒',
                    value: stats.requestsPerSec.toStringAsFixed(1),
                    subtitle: 'req/s',
                    icon: Icons.speed,
                    color: AdminTheme.infoColor,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildMetricCard(
                    context,
                    title: '平均响应时间',
                    value: stats.avgResponseTime.toStringAsFixed(0),
                    subtitle: 'ms',
                    icon: Icons.timer,
                    color: AdminTheme.successColor,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildMetricCard(
                    context,
                    title: '错误率',
                    value: stats.errorRate.toStringAsFixed(2),
                    subtitle: '%',
                    icon: Icons.error_outline,
                    color: stats.errorRate > 5
                        ? AdminTheme.errorColor
                        : stats.errorRate > 1
                            ? AdminTheme.warningColor
                            : AdminTheme.successColor,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRealtimeConnectionsSection(BuildContext context, RealtimeStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, '实时连接', Icons.hub, AdminTheme.secondaryColor),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth >= 900 ? 3 : 1;
            final cardWidth = crossAxisCount == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - (16 * (crossAxisCount - 1))) / crossAxisCount;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _buildMetricCard(
                    context,
                    title: 'WebSocket 连接',
                    value: stats.websocketConnections.toString(),
                    subtitle: 'connections',
                    icon: Icons.cable,
                    color: AdminTheme.primaryColor,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildMetricCard(
                    context,
                    title: '在线用户',
                    value: stats.onlineUsers.toString(),
                    subtitle: 'users',
                    icon: Icons.people,
                    color: AdminTheme.successColor,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildMetricCard(
                    context,
                    title: '活跃通话房间',
                    value: stats.activeRooms.toString(),
                    subtitle: 'rooms',
                    icon: Icons.video_call,
                    color: AdminTheme.warningColor,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const Spacer(),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AdminTheme.textTertiary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        _buildLoadingSection(3),
        const SizedBox(height: 24),
        _buildLoadingSection(3),
        const SizedBox(height: 24),
        _buildLoadingSection(3),
      ],
    );
  }

  Widget _buildLoadingSection(int count) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AdminTheme.glassBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 120,
                height: 20,
                decoration: BoxDecoration(
                  color: AdminTheme.glassBackground,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(
              count,
              (_) => SizedBox(
                width: 200,
                height: 150,
                child: Container(
                  decoration: BoxDecoration(
                    color: AdminTheme.glassBackground,
                    borderRadius: BorderRadius.circular(AdminTheme.borderRadiusMedium),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AdminTheme.errorColor),
          const SizedBox(height: 16),
          Text(
            '连接失败',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(monitorDataProvider);
              _startAutoRefresh();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重新连接'),
          ),
        ],
      ),
    );
  }

  Color _getResourceColor(double value) {
    if (value >= 80) return AdminTheme.errorColor;
    if (value >= 60) return AdminTheme.warningColor;
    return AdminTheme.successColor;
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}

class _CircularGaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final Color backgroundColor;

  _CircularGaugePainter({
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final foregroundPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final sweepAngle = (value / 100) * 2 * 3.14159;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      sweepAngle,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularGaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}