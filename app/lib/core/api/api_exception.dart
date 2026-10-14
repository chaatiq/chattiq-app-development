import 'package:dio/dio.dart';

enum ApiErrorCode { network, timeout, unauthorized, forbidden, notFound, validation, rateLimited, server, unknown }

const _fallbackMessages = <ApiErrorCode, String>{
  ApiErrorCode.network: "Can't reach the server. Check your internet connection and try again.",
  ApiErrorCode.timeout: 'The server took too long to respond. Try again.',
  ApiErrorCode.unauthorized: 'Your session has expired. Please log in again.',
  ApiErrorCode.forbidden: "You don't have access to this.",
  ApiErrorCode.notFound: "We couldn't find what you were looking for.",
  ApiErrorCode.validation: 'Please check the details and try again.',
  ApiErrorCode.rateLimited: 'Too many attempts. Please wait a moment and try again.',
  ApiErrorCode.server: 'Something went wrong on our side. Try again in a moment.',
  ApiErrorCode.unknown: 'Something went wrong. Try again.',
};

/// Every failed API call surfaces as this, with a message safe to show the user.
class ApiException implements Exception {
  ApiException(this.message, {required this.code, this.status = 0, this.data});

  final String message;
  final ApiErrorCode code;
  final int status;

  /// Decoded response body, when there was one.
  final Object? data;

  static ApiErrorCode codeForStatus(int status) {
    if (status == 401) return ApiErrorCode.unauthorized;
    if (status == 403) return ApiErrorCode.forbidden;
    if (status == 404) return ApiErrorCode.notFound;
    if (status == 400 || status == 422) return ApiErrorCode.validation;
    if (status == 429) return ApiErrorCode.rateLimited;
    if (status >= 500) return ApiErrorCode.server;
    return ApiErrorCode.unknown;
  }

  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(_fallbackMessages[ApiErrorCode.timeout]!, code: ApiErrorCode.timeout);
      case DioExceptionType.connectionError:
        return ApiException(_fallbackMessages[ApiErrorCode.network]!, code: ApiErrorCode.network);
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        final data = error.response?.data;
        final code = codeForStatus(status);
        return ApiException(_messageFrom(data) ?? _fallbackMessages[code]!, code: code, status: status, data: data);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return ApiException(_fallbackMessages[ApiErrorCode.network]!, code: ApiErrorCode.network);
    }
  }

  /// The server sends errors as { message } (Express) or { detail } (FastAPI).
  static String? _messageFrom(Object? data) {
    if (data is Map) {
      for (final key in const ['message', 'detail', 'error']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value;
      }
    }
    return null;
  }

  @override
  String toString() => 'ApiException($status, $code): $message';
}

/// A message that is safe to show to the user for any thrown value.
String userFacingMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is DioException) return ApiException.fromDio(error).message;
  return _fallbackMessages[ApiErrorCode.unknown]!;
}
