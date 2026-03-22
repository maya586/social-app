import 'package:dio/dio.dart';
import '../storage/admin_token_storage.dart';

class AdminApiClient {
  static final AdminApiClient _instance = AdminApiClient._internal();
  factory AdminApiClient() => _instance;

  late final Dio _dio;

  AdminApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: 'http://23.95.170.176:8080/api/v1',
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
        if (!options.path.contains('/admin/login')) {
          final token = await AdminTokenStorage().getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.type == DioExceptionType.badResponse &&
            error.response?.statusCode == 401) {
          await AdminTokenStorage().clearTokens();
        }
        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;
}