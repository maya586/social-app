import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/admin_api_client.dart';

class DashboardStats {
  final int totalUsers;
  final int todayRegistrations;
  final int onlineUsers;
  final int totalMessages;
  final int todayMessages;
  final List<DailyStats> userGrowth;
  final List<DailyStats> messageTrend;

  const DashboardStats({
    required this.totalUsers,
    required this.todayRegistrations,
    required this.onlineUsers,
    required this.totalMessages,
    required this.todayMessages,
    required this.userGrowth,
    required this.messageTrend,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalUsers: json['total_users'] as int? ?? 0,
      todayRegistrations: json['today_registrations'] as int? ?? 0,
      onlineUsers: json['online_users'] as int? ?? 0,
      totalMessages: json['total_messages'] as int? ?? 0,
      todayMessages: json['today_messages'] as int? ?? 0,
      userGrowth: (json['user_growth'] as List<dynamic>?)
              ?.map((e) => DailyStats.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      messageTrend: (json['message_trend'] as List<dynamic>?)
              ?.map((e) => DailyStats.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DailyStats {
  final String date;
  final int count;

  const DailyStats({required this.date, required this.count});

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      date: json['date'] as String? ?? '',
      count: json['count'] as int? ?? 0,
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