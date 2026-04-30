import 'dart:convert';
import 'dart:typed_data';

import 'package:don1ng_linkbox/onenet/token_log_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses OneNET token log fields with Chinese colons', () async {
    const text = '''
res：products/5X53hoeOP1/devices/don1ng
et：1830268800
key：RHN5YlNhV3FiemVDNDBrNFBseWF4WXB5UzJZMnJlekg=
method:md5
version:2018-10-31
Token：version=2018-10-31&res=products%2F5X53hoeOP1%2Fdevices%2Fdon1ng&et=1830268800&method=md5&sign=abc
''';

    final info = await TokenLogParser()
        .parseBytes(Uint8List.fromList(utf8.encode(text)));

    expect(info.productId, '5X53hoeOP1');
    expect(info.deviceName, 'don1ng');
    expect(info.deviceKey, 'RHN5YlNhV3FiemVDNDBrNFBseWF4WXB5UzJZMnJlekg=');
    expect(info.method, 'md5');
    expect(info.version, '2018-10-31');
    expect(info.expiresAt, isNotNull);
  });

  test('parses OneNET token log fields with English colons', () async {
    const text = '''
res: products/5X53hoeOP1/devices/don1ng
et: 1830268800
key: RHN5YlNhV3FiemVDNDBrNFBseWF4WXB5UzJZMnJlekg=
method: md5
version: 2018-10-31
Token: version=2018-10-31&res=products%2F5X53hoeOP1%2Fdevices%2Fdon1ng&et=1830268800&method=md5&sign=abc
''';

    final info = await TokenLogParser()
        .parseBytes(Uint8List.fromList(utf8.encode(text)));

    expect(info.productId, '5X53hoeOP1');
    expect(info.deviceName, 'don1ng');
    expect(info.token, startsWith('version=2018-10-31'));
  });

  test('repairs common mojibake colon output', () async {
    const text = '''
res锛歱roducts/5X53hoeOP1/devices/don1ng
et锛?830268800
key锛歊HN5YlNhV3FiemVDNDBrNFBseWF4WXB5UzJZMnJlekg=
method:md5
version:2018-10-31
Token锛歷ersion=2018-10-31&res=products%2F5X53hoeOP1%2Fdevices%2Fdon1ng&et=1830268800&method=md5&sign=abc
''';

    final info = await TokenLogParser()
        .parseBytes(Uint8List.fromList(utf8.encode(text)));

    expect(info.productId, '5X53hoeOP1');
    expect(info.deviceName, 'don1ng');
    expect(info.deviceKey, 'RHN5YlNhV3FiemVDNDBrNFBseWF4WXB5UzJZMnJlekg=');
    expect(info.expiresAt, isNotNull);
  });

  test('parses token-only logs', () async {
    const text =
        'Token: version=2018-10-31&res=products%2F5X53hoeOP1%2Fdevices%2Fdon1ng&et=1830268800&method=md5&sign=abc';

    final info = await TokenLogParser()
        .parseBytes(Uint8List.fromList(utf8.encode(text)));

    expect(info.productId, '5X53hoeOP1');
    expect(info.deviceName, 'don1ng');
    expect(info.deviceKey, isEmpty);
    expect(info.method, 'md5');
    expect(info.version, '2018-10-31');
  });

  test('parses expired token timestamp', () async {
    const text =
        'Token: version=2018-10-31&res=products%2F5X53hoeOP1%2Fdevices%2Fdon1ng&et=1&method=md5&sign=abc';

    final info = await TokenLogParser()
        .parseBytes(Uint8List.fromList(utf8.encode(text)));

    expect(info.expiresAt, DateTime.fromMillisecondsSinceEpoch(1000));
  });

  test('throws when res is missing', () async {
    const text = 'Token: version=2018-10-31&et=1830268800&method=md5&sign=abc';

    expect(
      () => TokenLogParser().parseBytes(
        Uint8List.fromList(utf8.encode(text)),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
