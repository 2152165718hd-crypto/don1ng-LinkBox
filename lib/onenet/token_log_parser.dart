import 'dart:convert';
import 'dart:typed_data';

class TokenLogInfo {
  const TokenLogInfo({
    required this.productId,
    required this.deviceName,
    this.deviceKey = '',
    this.token = '',
    this.method = 'md5',
    this.version = '2018-10-31',
    this.expiresAt,
  });

  final String productId;
  final String deviceName;
  final String deviceKey;
  final String token;
  final String method;
  final String version;
  final DateTime? expiresAt;
}

class TokenLogParser {
  Future<TokenLogInfo> parseBytes(Uint8List bytes) async {
    final text = await _decodeText(bytes);
    final fields = <String, String>{};
    for (final rawLine in const LineSplitter().convert(text)) {
      final parsed = _parseLine(rawLine);
      if (parsed == null) continue;
      fields[parsed.key] = parsed.value;
    }

    final token = fields['token'] ?? '';
    final res = fields['res'] ?? _tokenParam(token, 'res');
    final match = RegExp(r'products/([^/]+)/devices/(.+)$')
        .firstMatch(Uri.decodeComponent(res));
    if (match == null) {
      throw const FormatException(
          'Token.log 中未找到 res: products/{ProductID}/devices/{DeviceName}');
    }
    final expires = int.tryParse(fields['et'] ?? _tokenParam(token, 'et'));
    return TokenLogInfo(
      productId: match.group(1) ?? '',
      deviceName: match.group(2) ?? '',
      deviceKey: fields['key'] ?? '',
      token: token,
      method: fields['method'] ?? _tokenParam(token, 'method').ifEmpty('md5'),
      version: fields['version'] ??
          _tokenParam(token, 'version').ifEmpty('2018-10-31'),
      expiresAt: expires == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expires * 1000),
    );
  }

  _TokenLogLine? _parseLine(String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty) return null;
    var index = line.indexOf(':');
    if (index < 0) index = line.indexOf('：');
    if (index <= 0) {
      index = line.indexOf('锛');
      if (index <= 0) return null;
    }
    final key = line.substring(0, index).trim().toLowerCase();
    var value = line.substring(index + 1).trim();
    value = _repairCommonMojibakeValue(key, value);
    return _TokenLogLine(key, value);
  }

  String _repairCommonMojibakeValue(String key, String value) {
    if (value.isEmpty) return value;
    if (key == 'res' && !value.startsWith('products/')) {
      final index = value.indexOf('roducts/');
      if (index >= 0) return 'p${value.substring(index)}';
    }
    if (key == 'et' && int.tryParse(value) == null) {
      final match = RegExp(r'\d+').firstMatch(value);
      if (match != null) return match.group(0) ?? value;
    }
    if (key == 'key') {
      final index = value.indexOf('HN');
      if (value.startsWith('歊') && index >= 0) {
        return 'R${value.substring(index)}';
      }
    }
    if (key == 'token' && !value.startsWith('version=')) {
      final index = value.indexOf('ersion=');
      if (index >= 0) return 'v${value.substring(index)}';
    }
    return value;
  }

  String _tokenParam(String? token, String key) {
    if (token == null || token.isEmpty) return '';
    for (final part in token.split('&')) {
      final index = part.indexOf('=');
      if (index <= 0) continue;
      if (part.substring(0, index) == key) {
        return Uri.decodeComponent(part.substring(index + 1));
      }
    }
    return '';
  }

  Future<String> _decodeText(Uint8List bytes) async {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }
}

class _TokenLogLine {
  const _TokenLogLine(this.key, this.value);

  final String key;
  final String value;
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
