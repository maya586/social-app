import 'package:dio/dio.dart';
import 'api_config.dart';
import '../storage/token_storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  
  late final Dio _dio;
  static bool _isRefreshing = false;
  
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.path != '/auth/refresh-token' && _isRefreshing) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        final token = await TokenStorage().getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (error, handler) async {
        if (error.type == DioExceptionType.badResponse && error.response?.statusCode == 401) {
          if (!_isRefreshing) {
            _isRefreshing = true;
            final refreshToken = await TokenStorage().getRefreshToken();
            if (refreshToken != null) {
              try {
                final response = await _dio.post('/auth/refresh-token', 
                  data: {'refresh_token': refreshToken});
                final newAccessToken = response.data['data']['access_token'];
                final newRefreshToken = response.data['data']['refresh_token'];
                await TokenStorage().saveTokens(newAccessToken, newRefreshToken);
                _isRefreshing = false;
                
                error.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                return handler.resolve(await _dio.fetch(error.requestOptions));
              } catch (e) {
                _isRefreshing = false;
                await TokenStorage().clearTokens();
              }
            } else {
              _isRefreshing = false;
              await TokenStorage().clearTokens();
            }
          }
        }
        return handler.next(error);
      },
    ));
  }
  
  Dio get dio => _dio;
}