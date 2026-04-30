import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../storage/models.dart';

class OnenetAuth {
  const OnenetAuth({
    this.version = '2020-05-29',
    this.method = 'sha1',
    this.ttlSeconds = 86400,
  });

  final String version;
  final String method;
  final int ttlSeconds;

  String generateAuthorization(ProjectConfig config, {DateTime? now}) {
    if (config.authMode == AuthMode.deviceToken) {
      return generateDeviceToken(config, now: now);
    }
    return generateApplicationAuthorization(config, now: now);
  }

  String generateApplicationAuthorization(ProjectConfig config,
      {DateTime? now}) {
    if (!config.isReady) {
      throw const FormatException('OneNET 配置不完整，无法生成鉴权参数');
    }
    final effectiveTime =
        ((now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000) + ttlSeconds;
    final resource = config.resource;
    final stringForSignature = '$effectiveTime\n$method\n$resource\n$version';
    final List<int> keyBytes;
    try {
      keyBytes = base64Decode(config.accessKey.trim());
    } on FormatException {
      throw const FormatException('AccessKey 格式错误，必须是合法的 Base64 编码');
    }
    final digest = Hmac(_hashAlgorithm(method), keyBytes)
        .convert(utf8.encode(stringForSignature))
        .bytes;
    final sign = Uri.encodeComponent(base64Encode(digest));
    final encodedResource = Uri.encodeComponent(resource);
    return 'version=$version&res=$encodedResource&et=$effectiveTime&method=$method&sign=$sign';
  }

  String generateDeviceToken(ProjectConfig config, {DateTime? now}) {
    final productId = config.productId.trim();
    final deviceName = config.deviceName.trim();
    if (productId.isEmpty || deviceName.isEmpty) {
      throw const FormatException('Product ID 和 Device Name 不能为空');
    }

    final importedToken = config.deviceToken.trim();
    final deviceKey = config.deviceKey.trim();
    if (deviceKey.isEmpty) {
      final expiresAt = config.deviceTokenExpiresAt;
      if (importedToken.isEmpty) {
        throw const FormatException('Token.log 中缺少 key 或 Token');
      }
      if (expiresAt != null && !expiresAt.isAfter(now ?? DateTime.now())) {
        throw const FormatException('Token.log 中的 Token 已过期，请重新生成后导入');
      }
      return importedToken;
    }

    final tokenVersion = config.deviceTokenVersion.trim().isEmpty
        ? '2018-10-31'
        : config.deviceTokenVersion.trim();
    final tokenMethod = config.deviceTokenMethod.trim().isEmpty
        ? 'md5'
        : config.deviceTokenMethod.trim();
    final effectiveTime =
        ((now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000) + ttlSeconds;
    final resource = 'products/$productId/devices/$deviceName';
    final stringForSignature =
        '$effectiveTime\n$tokenMethod\n$resource\n$tokenVersion';
    final List<int> keyBytes;
    try {
      keyBytes = base64Decode(deviceKey);
    } on FormatException {
      throw const FormatException('DeviceKey 格式错误，必须是合法的 Base64 编码');
    }
    final digest = Hmac(_hashAlgorithm(tokenMethod), keyBytes)
        .convert(utf8.encode(stringForSignature))
        .bytes;
    final sign = Uri.encodeComponent(base64Encode(digest));
    final encodedResource = Uri.encodeComponent(resource);
    return 'version=$tokenVersion&res=$encodedResource&et=$effectiveTime&method=$tokenMethod&sign=$sign';
  }

  Hash _hashAlgorithm(String method) {
    switch (method.toLowerCase()) {
      case 'md5':
        return md5;
      case 'sha1':
        return sha1;
      case 'sha256':
        return sha256;
      default:
        throw FormatException('不支持的 OneNET 签名算法: $method');
    }
  }
}
