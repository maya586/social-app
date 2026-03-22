import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/admin_api_client.dart';

class SystemConfig {
  final String key;
  final String value;
  final String? description;
  final DateTime? updatedAt;

  const SystemConfig({
    required this.key,
    required this.value,
    this.description,
    this.updatedAt,
  });

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    return SystemConfig(
      key: json['key'] as String? ?? '',
      value: json['value'] as String? ?? '',
      description: json['description'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  bool get boolValue => value == 'true' || value == '1';

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
      };
}

class SettingsRepository {
  final AdminApiClient _apiClient;

  SettingsRepository({AdminApiClient? apiClient})
      : _apiClient = apiClient ?? AdminApiClient();

  Future<List<SystemConfig>> getConfigs() async {
    final response = await _apiClient.dio.get('/admin/configs');
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => SystemConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SystemConfig> updateConfig(String key, String value) async {
    final response = await _apiClient.dio.put(
      '/admin/configs/$key',
      data: {'value': value},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return SystemConfig.fromJson(data);
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final configsProvider = FutureProvider<List<SystemConfig>>((ref) async {
  final repository = ref.watch(settingsRepositoryProvider);
  return repository.getConfigs();
});

final configUpdateProvider =
    StateNotifierProvider<ConfigUpdateNotifier, AsyncValue<void>>((ref) {
  return ConfigUpdateNotifier(ref.watch(settingsRepositoryProvider));
});

class ConfigUpdateNotifier extends StateNotifier<AsyncValue<void>> {
  final SettingsRepository _repository;

  ConfigUpdateNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<bool> updateConfig(String key, String value) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateConfig(key, value);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}