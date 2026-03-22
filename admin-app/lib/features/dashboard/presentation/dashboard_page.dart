import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/stat_card.dart';
import '../data/dashboard_repository.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

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
              statsAsync.when(
                data: (stats) => _buildContent(context, stats),
                loading: () => _buildLoadingState(),
                error: (error, _) => _buildErrorState(context, ref, error),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '仪表盘',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '欢迎回来，管理员',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, DashboardStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatCards(context, stats),
        const SizedBox(height: 24),
        _buildChartsSection(context, stats),
      ],
    );
  }

  Widget _buildStatCards(BuildContext context, DashboardStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1200
            ? 5
            : constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 600
                    ? 2
                    : 1;

        final cardWidth = (constraints.maxWidth - (16 * (crossAxisCount - 1))) / crossAxisCount;

        final cards = [
          StatCard(
            title: '总用户',
            value: _formatNumber(stats.totalUsers),
            icon: Icons.people,
            color: AdminTheme.primaryColor,
          ),
          StatCard(
            title: '今日注册',
            value: _formatNumber(stats.todayNewUsers),
            icon: Icons.person_add,
            color: AdminTheme.successColor,
            subtitle: '今日',
          ),
          StatCard(
            title: '在线用户',
            value: _formatNumber(stats.onlineUsers),
            icon: Icons.circle,
            color: AdminTheme.infoColor,
          ),
          StatCard(
            title: '总消息',
            value: _formatNumber(stats.totalMessages),
            icon: Icons.message,
            color: AdminTheme.warningColor,
          ),
          StatCard(
            title: '今日消息',
            value: _formatNumber(stats.todayMessages),
            icon: Icons.chat_bubble,
            color: AdminTheme.secondaryColor,
            subtitle: '今日',
          ),
        ];

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards.map((card) {
            return SizedBox(width: cardWidth, child: card);
          }).toList(),
        );
      },
    );
  }

  Widget _buildChartsSection(BuildContext context, DashboardStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildUserGrowthChart(context, stats)),
              const SizedBox(width: 16),
              Expanded(child: _buildMessageTrendChart(context, stats)),
            ],
          );
        }
        return Column(
          children: [
            _buildUserGrowthChart(context, stats),
            const SizedBox(height: 16),
            _buildMessageTrendChart(context, stats),
          ],
        );
      },
    );
  }

  Widget _buildUserGrowthChart(BuildContext context, DashboardStats stats) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.trending_up, color: AdminTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                '7天用户增长趋势',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: stats.userTrend.isEmpty
                ? _buildEmptyChart()
                : _buildLineChart(
                    stats.userTrend,
                    AdminTheme.primaryColor,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTrendChart(BuildContext context, DashboardStats stats) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminTheme.warningColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chat, color: AdminTheme.warningColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                '7天消息发送趋势',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: stats.messageTrend.isEmpty
                ? _buildEmptyChart()
                : _buildLineChart(
                    stats.messageTrend,
                    AdminTheme.warningColor,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<int> data, Color color) {
    if (data.isEmpty) return _buildEmptyChart();

    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.toDouble());
    }).toList();

    final maxY = data.reduce((a, b) => a > b ? a : b);
    final interval = maxY > 0 ? (maxY / 4).ceilToDouble() : 1.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval > 0 ? interval : 1,
          getDrawingHorizontalLine: (value) {
            return const FlLine(
              color: AdminTheme.glassBorder,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox();
                }
                final days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    days[index],
                    style: const TextStyle(
                      color: AdminTheme.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval > 0 ? interval : 1,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatAxisValue(value),
                  style: const TextStyle(
                    color: AdminTheme.textTertiary,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxY > 0 ? maxY.toDouble() * 1.2 : 10,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: color,
                  strokeWidth: 2,
                  strokeColor: AdminTheme.surfaceColor,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: AdminTheme.cardColor,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toInt()}',
                  TextStyle(color: color, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChart() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 48, color: AdminTheme.textTertiary),
          SizedBox(height: 8),
          Text(
            '暂无数据',
            style: TextStyle(color: AdminTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        _buildLoadingCards(),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildLoadingChart()),
            const SizedBox(width: 16),
            Expanded(child: _buildLoadingChart()),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(
            5,
            (_) => SizedBox(
              width: (constraints.maxWidth - (16 * 4)) / 5,
              child: const StatCard(
                title: '加载中...',
                value: '---',
                icon: Icons.data_usage,
                isLoading: true,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingChart() {
    return const GlassContainer(
      padding: EdgeInsets.all(20),
      height: 284,
      child: Center(
        child: CircularProgressIndicator(color: AdminTheme.primaryColor),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
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
            onPressed: () => ref.invalidate(dashboardStatsProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _formatAxisValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(0)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toInt().toString();
  }
}