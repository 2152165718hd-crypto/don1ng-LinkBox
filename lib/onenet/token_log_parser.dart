import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';

class TokenLogInfo {
  const TokenLogInfo({
    required this.productId,
    required this.deviceName,
    this.deviceKey = '',
    this.token = '',
    this.expiresAt,
  });

  final String productId;
  final String deviceName;
  final String deviceKey;
  final String token;
  final DateTime? expiresAt;
}

class TokenLogParser {
  Future<TokenLogInfo> parseBytes(Uint8List bytes) async {
    final text = await _decodeText(bytes);
    final normalized = text.replaceAll('：', ':');
    final fields = <String, String>{};
    for (final rawLine in const LineSplitter().convert(normalized)) {
      final line = rawLine.trim();
      final index = line.indexOf(':');
      if (index <= 0) continue;
      final key = line.substring(0, index).trim().toLowerCase();
      final value = line.substring(index + 1).trim();
      fields[key] = value;
    }

    final res = fields['res'] ?? _tokenParam(fields['token'], 'res');
    final match = RegExp(r'products/([^/]+)/devices/(.+)$').firstMatch(Uri.decodeComponent(res));
    if (match == null) {
      throw const FormatException('Token.log 中未找到 res: products/{ProductID}/devices/{DeviceName}');
    }
    final expires = int.tryParse(fields['et'] ?? _tokenParam(fields['token'], 'et'));
    return TokenLogInfo(
      productId: match.group(1) ?? '',
      deviceName: match.group(2) ?? '',
      deviceKey: fields['key'] ?? '',
      token: fields['token'] ?? '',
      expiresAt: expires == null ? null : DateTime.fromMillisecondsSinceEpoch(expires * 1000),
    );
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
      for (final charset in const ['GBK', 'GB18030']) {
        try {
          return CharsetConverter.decode(charset, bytes);
        } catch (_) {
          // Try the next charset.
        }
      }
      return utf8.decode(bytes, allowMalformed: true);
    }
  }
}
