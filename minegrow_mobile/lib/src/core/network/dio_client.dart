import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'app_logger.dart';

final dioProvider = Provider<Dio>((ref) {
  final logger = ref.watch(loggerProvider);

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
      onRequest: (options, handler) {
        logger.d('${options.method} ${options.uri}');
        handler.next(options);
      },
      onError: (error, handler) {
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
