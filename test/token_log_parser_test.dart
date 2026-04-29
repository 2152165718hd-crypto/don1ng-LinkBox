import 'dart:convert';
import 'dart:typed_data';

import 'package:don1ng_linkbox/onenet/token_log_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses OneNET token log fields', () async {
    const text = '''
res：products/5X53hoeOP1/devices/don1ng
et：1830268800
key：RHN5YlNhV3FiemVDNDBrNFBseWF4WXB5UzJZMnJlekg=
method:md5
version:2018-10-31
Token：version=2018-10-31&res=products%2F5X53hoeOP1%2Fdevices%2Fdon1ng&et=1830268800&method=md5&sign=abc
''';

    final info = await TokenLogParser().parseBytes(Uint8List.fromList(utf8.encode(text)));

    expect(info.productId, '5X53hoeOP1');
    expect(info.deviceName, 'don1ng');
    expect(info.deviceKey, isNotEmpty);
    expect(info.expiresAt, isNotNull);
  });
}
