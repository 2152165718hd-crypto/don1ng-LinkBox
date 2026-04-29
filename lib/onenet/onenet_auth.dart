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
