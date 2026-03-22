import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/admin_api_client.dart';
import '../storage/admin_token_storage.dart';

class AdminAuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? adminId;
  final String? nickname;
  final String? error;

  const AdminAuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.adminId,
    this.nickname,
    this.error,
  });

  AdminAuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? adminId,
    String? nickname,
    String? error,
  }) {
    return AdminAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      adminId: adminId ?? this.adminId,
      nickname: nickname ?? this.nickname,
      error: error,
    );
  }
}

class AdminAuthNotifier extends StateNotifier<AdminAuthState> {
  final AdminApiClient _apiClient;
  final AdminTokenStorage _tokenStorage;

  AdminAuthNotifier({
    AdminApiClient? apiClient,
    AdminTokenStorage? tokenStorage,
  })  : _apiClient = apiClient ?? AdminApiClient(),
        _tokenStorage = tokenStorage ?? AdminTokenStorage(),
        super(const AdminAuthState());

  Future<bool> checkAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      final hasToken = await _tokenStorage.hasToken();
      if (hasToken) {
        final adminId = await _tokenStorage.getAdminId();
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          adminId: adminId,
        );
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiClient.dio.post(
        '/admin/login',
        data: {
          'username': username,
          'password': password,
        },
      );

      final data = response.data['data'];
      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String;
      final adminId = data['admin_id']?.toString() ?? '';
      final nickname = data['nickname'] as String?;

      await _tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        adminId: adminId,
      );

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        adminId: adminId,
        nickname: nickname,
      );
      return true;
    } on DioException catch (e) {
      final errorMessage = e.response?.data['message'] ?? 'Login failed';
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _tokenStorage.clearTokens();
    state = const AdminAuthState();
  }
}

final adminAuthProvider =
    StateNotifierProvider<AdminAuthNotifier, AdminAuthState>((ref) {
  return AdminAuthNotifier();
});