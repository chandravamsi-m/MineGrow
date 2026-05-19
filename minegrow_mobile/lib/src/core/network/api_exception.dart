import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  factory ApiException.fromDioException(DioException exception) {
    final response = exception.response;
    final statusCode = response?.statusCode;

    return ApiException(
      message: _messageFor(exception),
      statusCode: statusCode,
      cause: exception,
    );
  }

  static String _messageFor(DioException exception) {
    return switch (exception.type) {
      DioExceptionType.connectionTimeout => 'Connection timed out.',
      DioExceptionType.sendTimeout => 'Request timed out while sending data.',
      DioExceptionType.receiveTimeout =>
        'Request timed out while receiving data.',
      DioExceptionType.badCertificate => 'The server certificate is invalid.',
      DioExceptionType.badResponse => _badResponseMessage(exception.response),
      DioExceptionType.cancel => 'Request was cancelled.',
      DioExceptionType.connectionError => 'Could not connect to the server.',
      DioExceptionType.unknown => 'Something went wrong. Please try again.',
    };
  }

  static String _badResponseMessage(Response<dynamic>? response) {
    final statusCode = response?.statusCode;
    if (statusCode == null) {
      return 'The server returned an invalid response.';
    }

    if (statusCode >= 500) {
      return 'The server is unavailable. Please try again later.';
    }

    if (statusCode == 401) {
      return 'Your session has expired. Please sign in again.';
    }

    if (statusCode == 403) {
      return 'You do not have permission to perform this action.';
    }

    if (statusCode == 404) {
      return 'The requested resource was not found.';
    }

    return 'Request failed with status code $statusCode.';
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
