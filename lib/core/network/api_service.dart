import 'package:dio/dio.dart';

import '../auth/auth_service.dart';
import '../config/env.dart';

class ApiService {
  final Dio _dio;

  ApiService._internal(this._dio) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        // ================================================================
        // REQUEST INTERCEPTOR
        // ================================================================

        onRequest: (options, handler) async {
          // --------------------------------------------------------------
          // 1. Automatically add /api/v1 prefix
          // --------------------------------------------------------------

          final path = options.path;

          if (!path.startsWith('/api/v1')) {
            if (path.startsWith('/')) {
              options.path = '/api/v1$path';
            } else {
              options.path = '/api/v1/$path';
            }
          }

          // --------------------------------------------------------------
          // 2. Automatically attach JWT
          // --------------------------------------------------------------

          final existingAuthorization =
          options.headers['Authorization'];

          if (existingAuthorization == null ||
              existingAuthorization.toString().trim().isEmpty) {
            try {
              final token = await AuthService.getToken();

              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] =
                'Bearer $token';
              }
            } catch (_) {
              // Continue without authentication
              // for public endpoints such as login.
            }
          }

          return handler.next(options);
        },

        // ================================================================
        // ERROR INTERCEPTOR
        // ================================================================

        onError: (err, handler) async {
          final status = err.response?.statusCode;

          // --------------------------------------------------------------
          // Invalid / expired JWT
          // --------------------------------------------------------------

          if (status == 401) {
            try {
              await AuthService.clearToken();
            } catch (_) {}
          }

          return handler.next(err);
        },
      ),
    );
  }

  // ================================================================
  // SINGLE DIO INSTANCE
  // ================================================================

  static final ApiService instance = ApiService._internal(
    Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,

        connectTimeout: const Duration(
          seconds: 30,
        ),

        receiveTimeout: const Duration(
          seconds: 30,
        ),

        sendTimeout: const Duration(
          seconds: 30,
        ),

        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    ),
  );

  Dio get client => _dio;

  // ================================================================
  // GET
  // ================================================================

  Future<Response> get(
      String path, {
        Map<String, dynamic>? queryParameters,
      }) async {
    return _dio.get(
      path,
      queryParameters: queryParameters,
    );
  }

  // ================================================================
  // POST
  // ================================================================

  Future<Response> post(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
      }) async {
    return _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
    );
  }

  // ================================================================
  // PATCH
  // ================================================================

  Future<Response> patch(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
      }) async {
    return _dio.patch(
      path,
      data: data,
      queryParameters: queryParameters,
    );
  }

  // ================================================================
  // DELETE
  // ================================================================

  Future<Response> delete(
      String path, {
        Map<String, dynamic>? queryParameters,
      }) async {
    return _dio.delete(
      path,
      queryParameters: queryParameters,
    );
  }
}