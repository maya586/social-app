import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/admin_api_client.dart';

class DashboardStats {
  final int totalUsers;
  final int todayNewUsers;
  final int onlineUsers;
  final int totalMessages;
  final int todayMessages;
  final int activeConversations;
  final List<int> userTrend;
  final List<int> messageTrend;

  const DashboardStats({
    required this.totalUsers,
    required this.todayNewUsers,
    required this.onlineUsers,
    required this.totalMessages,
    required this.todayMessages,
    required this.activeConversations,
    required this.userTrend,
    required this.messageTrend,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalUsers: (json['total_users'] ?? 0) as int,
      todayNewUsers: (json['today_new_users'] ?? 0) as int,
      onlineUsers: (json['online_users'] ?? 0) as int,
      totalMessages: (json['total_messages'] ?? 0) as int,
      todayMessages: (json['today_messages'] ?? 0) as int,
      activeConversations: (json['active_conversations'] ?? 0) as int,
      userTrend: (json['user_trend'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      messageTrend: (json['message_trend'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
    );
  }
}

class DashboardRepository {
  final AdminApiClient _apiClient;

  DashboardRepository({AdminApiClient? apiClient})
      : _apiClient = apiClient ?? AdminApiClient();

  Future<DashboardStats> getDashboardStats() async {
    final response = await _apiClient.dio.get('/admin/dashboard');
    final data = response.data['data'] as Map<String, dynamic>;
    return DashboardStats.fromJson(data);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  return repository.getDashboardStats();
});