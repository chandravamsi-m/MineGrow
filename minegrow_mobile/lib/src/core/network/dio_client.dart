import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/local_storage.dart';
import 'api_exception.dart';
import 'app_logger.dart';

final dioProvider = Provider<Dio>((ref) {
  final logger = ref.watch(loggerProvider);
  final storage = ref.watch(localStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: AppConfig.networkTimeout,
      receiveTimeout: AppConfig.networkTimeout,
      sendTimeout: AppConfig.networkTimeout,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // HIGH-3: Read token from encrypted secure storage (async)
        final accessToken = await storage.readStringAsync(
          AuthStorageKeys.accessToken,
        );
        if (accessToken != null && accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        logger.d('${options.method} ${options.uri}');
        handler.next(options);
      },
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode;
        final requestPath = error.requestOptions.path;

        // Attempt token refresh on 401, but never recurse into the refresh endpoint itself.
        if (statusCode == 401 && !requestPath.contains('/auth/refresh')) {
          try {
            final refreshToken = await storage.readStringAsync(
              AuthStorageKeys.refreshToken,
            );

            if (refreshToken == null || refreshToken.isEmpty) {
              await storage.removeAll();
              handler.next(error);
              return;
            }

            final refreshResponse = await dio.post<dynamic>(
              '/auth/refresh',
              data: {'refreshToken': refreshToken},
            );

            // NestJS TransformInterceptor wraps responses as
            // { success, data: { accessToken, refreshToken }, ... }
            final responseBody = refreshResponse.data as Map<String, dynamic>?;
            final payload =
                (responseBody?['data'] as Map<String, dynamic>?) ??
                responseBody;
            final newAccessToken = payload?['accessToken'] as String?;
            final newRefreshToken = payload?['refreshToken'] as String?;

            if (newAccessToken == null ||
                newAccessToken.isEmpty ||
                newRefreshToken == null ||
                newRefreshToken.isEmpty) {
              await storage.removeAll();
              handler.next(error);
              return;
            }

            await storage.writeString(
              AuthStorageKeys.accessToken,
              newAccessToken,
            );
            await storage.writeString(
              AuthStorageKeys.refreshToken,
              newRefreshToken,
            );

            // Retry the original request with the fresh access token.
            error.requestOptions.headers['Authorization'] =
                'Bearer $newAccessToken';
            final retryResponse = await dio.fetch(error.requestOptions);
            handler.resolve(retryResponse);
            return;
          } catch (_) {
            // Refresh failed (token expired / revoked) — clear session.
            await storage.removeAll();
          }
        }

        logger.e(
          '${error.requestOptions.method} ${error.requestOptions.uri}',
          error: error,
          stackTrace: error.stackTrace,
        );
        handler.next(error);
      },
    ),
  );

  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

abstract final class AuthStorageKeys {
  static const accessToken = 'auth.accessToken';
  static const refreshToken = 'auth.refreshToken';
  static const mobile = 'auth.mobile';
  static const otpPurpose = 'auth.otpPurpose';
  static const otpResendDelay = 'auth.otpResendDelay';
}

class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _request(
      () =>
          _dio.get<T>(path, queryParameters: queryParameters, options: options),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _request(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _request(
      () => _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _request(
      () => _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _request(
      () => _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  Future<T> getData<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(Object? json) parser,
  }) async {
    final response = await get<Object?>(path, queryParameters: queryParameters);
    return parser(_unwrapData(response.data));
  }

  Future<T> postData<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    required T Function(Object? json) parser,
  }) async {
    final response = await post<Object?>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
    return parser(_unwrapData(response.data));
  }

  Future<T> putData<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    required T Function(Object? json) parser,
  }) async {
    final response = await put<Object?>(
      path,
      data: data,
      queryParameters: queryParameters,
    );
    return parser(_unwrapData(response.data));
  }

  Future<T> patchData<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    required T Function(Object? json) parser,
  }) async {
    final response = await patch<Object?>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
    return parser(_unwrapData(response.data));
  }

  Object? _unwrapData(Object? body) {
    if (body case {
      'success': false,
      'error': {'message': final String message},
    }) {
      throw ApiException(message: message);
    }

    if (body case {'data': final Object? data}) {
      return data;
    }

    return body;
  }

  Future<Response<T>> _request<T>(
    Future<Response<T>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }
}
