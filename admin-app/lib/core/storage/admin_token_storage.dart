import 'package:shared_preferences/shared_preferences.dart';

class AdminTokenStorage {
  static final AdminTokenStorage _instance = AdminTokenStorage._internal();
  factory AdminTokenStorage() => _instance;

  AdminTokenStorage._internal();

  static const String _accessTokenKey = 'admin_access_token';
  static const String _refreshTokenKey = 'admin_refresh_token';
  static const String _adminIdKey = 'admin_id';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String adminId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setString(_adminIdKey, adminId);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<String?> getAdminId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_adminIdKey);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_adminIdKey);
  }

  Future<bool> hasToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}