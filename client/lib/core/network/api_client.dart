import 'package:dio/dio.dart';
import 'api_config.dart';
import '../storage/token_storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  
  late final Dio _dio;
  
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
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
          final refreshToken = await TokenStorage().getRefreshToken();
          if (refreshToken != null) {
            try {
              final response = await _dio.post('/auth/refresh-token', 
                data: {'refresh_token': refreshToken});
              final newAccessToken = response.data['data']['access_token'];
              final newRefreshToken = response.data['data']['refresh_token'];
              await TokenStorage().saveTokens(newAccessToken, newRefreshToken);
              
              error.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              return handler.resolve(await _dio.fetch(error.requestOptions));
            } catch (e) {
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