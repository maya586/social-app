import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthRepository _repository;
  
  AuthNotifier(this._repository) : super(const AsyncValue.data(null));
  
  Future<bool> checkAuth() async {
    final isAuth = await _repository.isAuthenticated();
    return isAuth;
  }
  
  Future<void> register({
    required String phone,
    required String password,
    required String nickname,
  }) async {
    state = const AsyncValue.loading();
    try {
      final data = await _repository.register(
        phone: phone,
        password: password,
        nickname: nickname,
      );
      final user = User.fromJson(data['user']);
      state = AsyncValue.data(user);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
  
  Future<void> login({
    required String phone,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final data = await _repository.login(
        phone: phone,
        password: password,
      );
      final user = User.fromJson(data['user']);
      state = AsyncValue.data(user);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
  
  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
  }
}