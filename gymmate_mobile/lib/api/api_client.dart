import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:gymmate_mobile/api/api_config.dart';

/// Typed error thrown by [ApiClient]. Carries the HTTP status code and a
/// user-facing message. `toString()` returns the message so existing UI that
/// does `_error = e.toString()` keeps showing something sensible.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final bool isNetwork;

  const ApiException(this.message, {this.statusCode, this.isNetwork = false});

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Thin shared HTTP wrapper used by the data services. Centralizes:
/// - request timeouts (so calls never hang on a flaky network),
/// - the `Authorization: Bearer` + JSON header pair,
/// - response decoding + error translation into [ApiException],
/// - a global 401 hook so an expired session can route the user to login.
class ApiClient {
  ApiClient._();

  /// Single source of truth for request timeout. Public so auth_service (which
  /// keeps its own bespoke parsing) can reuse it.
  static const Duration timeout = Duration(seconds: 15);

  /// Invoked once when any request returns 401. Wired in main.dart to log the
  /// user out (which rebuilds AuthGate back to the entry screen).
  static void Function()? onUnauthorized;

  static const String _networkMessage =
      'Network unavailable. Check your connection and try again.';

  static Map<String, String> headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Future<http.Response> get(
    String path, {
    String? token,
    Map<String, String>? extraHeaders,
  }) {
    return _send(
      () => http.get(_uri(path), headers: _mergedHeaders(token, extraHeaders)),
    );
  }

  static Future<http.Response> post(
    String path, {
    String? token,
    Object? body,
    Map<String, String>? extraHeaders,
  }) {
    return _send(
      () => http.post(
        _uri(path),
        headers: _mergedHeaders(token, extraHeaders),
        body: body is String || body == null ? body : json.encode(body),
      ),
    );
  }

  static Future<http.Response> put(
    String path, {
    String? token,
    Object? body,
    Map<String, String>? extraHeaders,
  }) {
    return _send(
      () => http.put(
        _uri(path),
        headers: _mergedHeaders(token, extraHeaders),
        body: body is String || body == null ? body : json.encode(body),
      ),
    );
  }

  static Future<http.Response> patch(
    String path, {
    String? token,
    Object? body,
    Map<String, String>? extraHeaders,
  }) {
    return _send(
      () => http.patch(
        _uri(path),
        headers: _mergedHeaders(token, extraHeaders),
        body: body is String || body == null ? body : json.encode(body),
      ),
    );
  }

  static Future<http.Response> delete(
    String path, {
    String? token,
    Object? body,
    Map<String, String>? extraHeaders,
  }) {
    return _send(
      () => http.delete(
        _uri(path),
        headers: _mergedHeaders(token, extraHeaders),
        body: body is String || body == null ? body : json.encode(body),
      ),
    );
  }

  static Map<String, String> _mergedHeaders(
    String? token,
    Map<String, String>? extra,
  ) {
    final base = token != null
        ? headers(token)
        : {'Content-Type': 'application/json'};
    if (extra != null) base.addAll(extra);
    return base;
  }

  /// Runs the request with a timeout and translates transport-level failures
  /// (timeout, no connection, DNS) into a network [ApiException].
  static Future<http.Response> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(_networkMessage, isNetwork: true);
    } on SocketException {
      throw const ApiException(_networkMessage, isNetwork: true);
    } on http.ClientException {
      throw const ApiException(_networkMessage, isNetwork: true);
    }
  }

  /// Decodes a JSON object response. On non-2xx throws [ApiException]; on an
  /// auth failure also fires [onUnauthorized]. Mirrors the old per-service
  /// `_decodeResponse`.
  static Map<String, dynamic> decode(http.Response res, String fallback) {
    Map<String, dynamic> payload = const {};
    if (res.body.isNotEmpty) {
      try {
        final decoded = json.decode(res.body);
        if (decoded is Map<String, dynamic>) payload = decoded;
      } catch (_) {
        // Non-JSON body; fall through to status-based handling.
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return payload;
    }

    final message = (payload['message'] as String?) ?? fallback;

    // The backend's auth middleware returns 401 OR 403 with a token-specific
    // message ("No token provided", "Invalid or expired token") when the
    // session is bad. A 403 WITHOUT a token message is a genuine permission
    // error (e.g. a member hitting an owner route) and must NOT log out.
    if (_isAuthFailure(res.statusCode, message)) {
      onUnauthorized?.call();
      throw ApiException(
        'Session expired. Please log in again.',
        statusCode: res.statusCode,
      );
    }

    throw ApiException(message, statusCode: res.statusCode);
  }

  static bool _isAuthFailure(int statusCode, String message) {
    if (statusCode == 401) return true;
    if (statusCode == 403) {
      return message.toLowerCase().contains('token');
    }
    return false;
  }
}
