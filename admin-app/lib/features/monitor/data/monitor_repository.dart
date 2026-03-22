import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/admin_api_client.dart';

class ServerStats {
  final double cpu;
  final double memory;
  final double disk;
  final NetworkStats network;

  const ServerStats({
    required this.cpu,
    required this.memory,
    required this.disk,
    required this.network,
  });

  factory ServerStats.fromJson(Map<String, dynamic> json) {
    return ServerStats(
      cpu: (json['cpu'] as num?)?.toDouble() ?? 0.0,
      memory: (json['memory'] as num?)?.toDouble() ?? 0.0,
      disk: (json['disk'] as num?)?.toDouble() ?? 0.0,
      network: NetworkStats.fromJson(json['network'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class NetworkStats {
  final int bytesIn;
  final int bytesOut;

  const NetworkStats({
    required this.bytesIn,
    required this.bytesOut,
  });

  factory NetworkStats.fromJson(Map<String, dynamic> json) {
    return NetworkStats(
      bytesIn: json['bytes_in'] as int? ?? 0,
      bytesOut: json['bytes_out'] as int? ?? 0,
    );
  }
}

class ApiStats {
  final double requestsPerSec;
  final double avgResponseTime;
  final double errorRate;

  const ApiStats({
    required this.requestsPerSec,
    required this.avgResponseTime,
    required this.errorRate,
  });

  factory ApiStats.fromJson(Map<String, dynamic> json) {
    return ApiStats(
      requestsPerSec: (json['requests_per_sec'] as num?)?.toDouble() ?? 0.0,
      avgResponseTime: (json['avg_response_time'] as num?)?.toDouble() ?? 0.0,
      errorRate: (json['error_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class RealtimeStats {
  final int websocketConnections;
  final int onlineUsers;
  final int activeRooms;

  const RealtimeStats({
    required this.websocketConnections,
    required this.onlineUsers,
    required this.activeRooms,
  });

  factory RealtimeStats.fromJson(Map<String, dynamic> json) {
    return RealtimeStats(
      websocketConnections: json['websocket_connections'] as int? ?? 0,
      onlineUsers: json['online_users'] as int? ?? 0,
      activeRooms: json['active_rooms'] as int? ?? 0,
    );
  }
}

class MonitorData {
  final ServerStats server;
  final ApiStats api;
  final RealtimeStats realtime;
  final DateTime timestamp;

  const MonitorData({
    required this.server,
    required this.api,
    required this.realtime,
    required this.timestamp,
  });

  factory MonitorData.fromJson(Map<String, dynamic> json) {
    return MonitorData(
      server: ServerStats.fromJson(json['server'] as Map<String, dynamic>? ?? {}),
      api: ApiStats.fromJson(json['api'] as Map<String, dynamic>? ?? {}),
      realtime: RealtimeStats.fromJson(json['realtime'] as Map<String, dynamic>? ?? {}),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

class MonitorRepository {
  final AdminApiClient _apiClient;

  MonitorRepository({AdminApiClient? apiClient})
      : _apiClient = apiClient ?? AdminApiClient();

  Future<MonitorData> getMonitorData() async {
    final response = await _apiClient.dio.get('/admin/monitor');
    final data = response.data['data'] as Map<String, dynamic>;
    return MonitorData.fromJson(data);
  }
}

final monitorRepositoryProvider = Provider<MonitorRepository>((ref) {
  return MonitorRepository();
});

final monitorDataProvider = FutureProvider<MonitorData>((ref) async {
  final repository = ref.watch(monitorRepositoryProvider);
  return repository.getMonitorData();
});