import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/env.dart';
import '../auth/token_storage.dart';
import 'api_exception.dart';

/// HTTP client for the mobile backend.
///
/// - Sends the access token as a Bearer header (unless `auth: false`).
/// - On a 401 it refreshes the session once and retries the request. Refresh
///   is single-flight: parallel 401s wait for one refresh instead of each
///   rotating the token.
/// - When the session can no longer be refreshed it calls [onSessionExpired].
/// - Every failure is thrown as [ApiException].
class ApiClient {
  ApiClient({required TokenStorage tokens, String? baseUrl, Dio? dio})
    : _tokens = tokens, // ignore: prefer_initializing_formals
      _dio = dio ?? Dio(_options(baseUrl ?? Env.apiUrl)),
      _plain = Dio(_options(baseUrl ?? Env.apiUrl)) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: _attachToken, onError: _refreshOn401));
  }

  static BaseOptions _options(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: apiTimeout,
    receiveTimeout: apiTimeout,
    sendTimeout: apiTimeout,
    headers: const {'Accept': 'application/json'},
  );

  final TokenStorage _tokens;
  final Dio _dio;

  /// No interceptors: used for refresh so it can never loop.
  final Dio _plain;

  @visibleForTesting
  Dio get refreshDioForTest => _plain;

  /// Called once the session is gone for good (user must log in again).
  void Function()? onSessionExpired;

  Future<String?>? _refreshInFlight;

  Future<void> _attachToken(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['auth'] != false) {
      final token = await _tokens.accessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _refreshOn401(DioException error, ErrorInterceptorHandler handler) async {
    final request = error.requestOptions;
    final canRetry =
        error.response?.statusCode == 401 &&
        request.extra['auth'] != false &&
        request.extra['retried'] != true &&
        request.headers['Authorization'] != null;
    if (!canRetry) return handler.next(error);

    final fresh = await refreshSession();
    if (fresh != null) {
      request.extra['retried'] = true;
      try {
        return handler.resolve(await _dio.fetch(request));
      } on DioException catch (retryError) {
        return handler.next(retryError);
      }
    }
    if (await _tokens.refreshToken() == null) onSessionExpired?.call();
    handler.next(error);
  }

  /// Swaps the refresh token for new tokens. Returns the new access token, or
  /// null when the session cannot be refreshed.
  Future<String?> refreshSession() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await _tokens.refreshToken();
    if (refreshToken == null) return null;
    try {
      final response = await _plain.post<Map<String, dynamic>>('/auth/refresh', data: {'refreshToken': refreshToken});
      final access = response.data?['accessToken'];
      final refresh = response.data?['refreshToken'];
      if (access is! String || refresh is! String) return null;
      await _tokens.save(TokenPair(accessToken: access, refreshToken: refresh));
      return access;
    } on DioException catch (error) {
      // 401/403: the refresh token is no longer valid. Other failures (server
      // down, no network) keep the stored tokens so the user is not logged out.
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) await _tokens.clear();
      return null;
    }
  }

  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool auth = true,
    Duration? timeout,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, extra: {'auth': auth}, receiveTimeout: timeout, sendTimeout: timeout),
      );
      return response.data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = true}) =>
      request('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path, {Object? body, bool auth = true, Duration? timeout}) =>
      request('POST', path, body: body, auth: auth, timeout: timeout);

  Future<dynamic> patch(String path, {Object? body}) => request('PATCH', path, body: body);

  Future<dynamic> delete(String path, {Duration? timeout}) => request('DELETE', path, timeout: timeout);
}
