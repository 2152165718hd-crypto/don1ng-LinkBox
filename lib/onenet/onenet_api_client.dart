import 'dart:convert';

import 'package:dio/dio.dart';

import '../storage/models.dart';
import 'onenet_auth.dart';

class OnenetApiException implements Exception {
  const OnenetApiException(this.message, {this.code, this.detail});

  final String message;
  final String? code;
  final Object? detail;

  @override
  String toString() => 'OnenetApiException($code, $message)';
}

class OnenetApiClient {
  OnenetApiClient({
    Dio? dio,
    OnenetAuth? auth,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://openapi.heclouds.com',
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
              ),
            ),
        _auth = auth ?? const OnenetAuth();

  final Dio _dio;
  final OnenetAuth _auth;

  Future<List<RuntimeValue>> queryLatest(ProjectConfig config) async {
    final payload = await _request(
      config,
      method: 'GET',
      action: 'QueryDeviceProperty',
      query: {
        'project_id': config.projectId,
        'product_id': config.productId,
        'device_name': config.deviceName,
      },
    );
    final list = _readDataList(payload);
    return list.map((item) {
      return RuntimeValue(
        identifier: item['identifier']?.toString() ?? '',
        value: _decodeJsonLike(item['value']),
        time: _parseMillis(item['time']),
      );
    }).where((item) => item.identifier.isNotEmpty).toList();
  }

  Future<List<RuntimeValue>> queryHistory({
    required ProjectConfig config,
    required String identifier,
    required DateTime start,
    required DateTime end,
    int limit = 100,
  }) async {
    final payload = await _request(
      config,
      method: 'GET',
      action: 'QueryDevicePropertyHistory',
      query: {
        'project_id': config.projectId,
        'product_id': config.productId,
        'device_name': config.deviceName,
        'identifier': identifier,
        'start_time': start.millisecondsSinceEpoch.toString(),
        'end_time': end.millisecondsSinceEpoch.toString(),
        'sort': '1',
        'limit': limit.toString(),
      },
    );
    final list = _readDataList(payload);
    return list.map((item) {
      return RuntimeValue(
        identifier: identifier,
        value: _decodeJsonLike(item['value']),
        time: _parseMillis(item['time']),
      );
    }).toList();
  }

  Future<void> setDeviceProperty({
    required ProjectConfig config,
    required String identifier,
    required Object? value,
  }) async {
    await _request(
      config,
      method: 'POST',
      action: 'SetDeviceProperty',
      body: {
        'project_id': config.projectId,
        'product_id': config.productId,
        'device_name': config.deviceName,
        'params': {
          identifier: value,
        },
      },
    );
  }

  Future<Map<String, Object?>> _request(
    ProjectConfig config, {
    required String method,
    required String action,
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        '/application',
        queryParameters: {
          'action': action,
          'version': '1',
          ...?query,
        },
        data: body,
        options: Options(
          method: method,
          headers: {
            'authorization': _auth.generateAuthorization(config),
            'Content-Type': 'application/json',
          },
        ),
      );
      final payload = _asMap(response.data);
      if (payload['success'] != true) {
        throw OnenetApiException(
          payload['msg']?.toString() ?? 'OneNET API 调用失败',
          code: payload['code']?.toString(),
          detail: payload,
        );
      }
      return payload;
    } on DioException catch (error) {
      final payload = _asMap(error.response?.data);
      throw OnenetApiException(
        payload['msg']?.toString() ?? error.message ?? '网络请求失败',
        code: payload['code']?.toString(),
        detail: error.response?.data ?? error,
      );
    }
  }

  Map<String, Object?> _asMap(Object? data) {
    if (data is Map<String, Object?>) return data;
    if (data is Map) return data.map((key, value) => MapEntry(key.toString(), value));
    if (data is String && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, Object?>{};
  }

  List<Map<String, Object?>> _readDataList(Map<String, Object?> payload) {
    final data = payload['data'];
    if (data is Map && data['list'] is List) {
      return (data['list'] as List)
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
          .toList();
    }
    return const [];
  }

  Object? _decodeJsonLike(Object? raw) {
    if (raw is! String) return raw;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    try {
      return jsonDecode(trimmed);
    } on FormatException {
      return raw;
    }
  }

  DateTime _parseMillis(Object? raw) {
    final millis = int.tryParse(raw?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
