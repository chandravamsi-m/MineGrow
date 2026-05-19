import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final httpApiClientProvider = Provider<HttpApiClient>((ref) {
  return HttpApiClient(ref.watch(httpClientProvider));
});

class HttpApiClient {
  const HttpApiClient(this._client);

  final http.Client _client;

  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) {
    return _client.get(_uri(path, queryParameters), headers: _headers(headers));
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) {
    return _client.post(
      _uri(path, queryParameters),
      headers: _headers(headers),
      body: body == null ? null : jsonEncode(body),
    );
  }

  Uri _uri(String path, Map<String, String>? queryParameters) {
    final base = Uri.parse(AppConfig.apiUrl);
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;

    return base.replace(
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        ...normalizedPath.split('/').where((segment) => segment.isNotEmpty),
      ],
      queryParameters: queryParameters,
    );
  }

  Map<String, String> _headers(Map<String, String>? headers) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...?headers,
    };
  }
}
