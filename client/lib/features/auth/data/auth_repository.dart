import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';

class AuthRepository {
  final _api = ApiClient().dio;
  final _tokenStorage = TokenStorage();
  
  Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    required String nickname,
  }) async {
    final response = await _api.post('/auth/register', data: {
      'phone': phone,
      'password': password,
      'nickname': nickname,
    });
    
    final data = response.data['data'];
    await _saveAuthData(data);
    return data;
  }
  
  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final response = await _api.post('/auth/login', data: {
      'phone': phone,
      'password': password,
    });
    
    final data = response.data['data'];
    await _saveAuthData(data);
    return data;
  }
  
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (e) {
      // Ignore errors during logout
    }
    await _tokenStorage.clearTokens();
  }
  
  Future<void> _saveAuthData(Map<String, dynamic> data) async {
    await _tokenStorage.saveTokens(
      data['access_token'],
      data['refresh_token'],
    );
    await _tokenStorage.saveUserId(data['user']['id']);
  }
  
  Future<bool> isAuthenticated() async {
    return await _tokenStorage.hasToken();
  }
}