import 'package:don1ng_linkbox/onenet/onenet_auth.dart';
import 'package:don1ng_linkbox/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates OneNET application authorization', () {
    final auth = const OnenetAuth(ttlSeconds: 60);
    final authorization = auth.generateAuthorization(
      const ProjectConfig(
        projectId: 'projectA',
        groupId: 'groupB',
        accessKey: 'dGVzdC1rZXk=',
        productId: 'productC',
        deviceName: 'deviceD',
        authMode: AuthMode.projectGroup,
      ),
      now: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    expect(authorization, contains('version=2020-05-29'));
    expect(
        authorization, contains('res=projectid%2FprojectA%2Fgroupid%2FgroupB'));
    expect(authorization, contains('et=1700000060'));
    expect(authorization, contains('method=sha1'));
    expect(authorization, contains('sign='));
  });

  test('generates OneNET device token authorization', () {
    final auth = const OnenetAuth(ttlSeconds: 60);
    final authorization = auth.generateAuthorization(
      const ProjectConfig(
        projectId: '',
        groupId: '',
        accessKey: '',
        productId: '5X53hoeOP1',
        deviceName: 'don1ng',
        deviceKey: 'RHN5YlNhV3FiemVDNDBrNFBseWF4WXB5UzJZMnJlekg=',
        deviceTokenMethod: 'md5',
        deviceTokenVersion: '2018-10-31',
      ),
      now: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    expect(authorization, contains('version=2018-10-31'));
    expect(authorization,
        contains('res=products%2F5X53hoeOP1%2Fdevices%2Fdon1ng'));
    expect(authorization, contains('et=1700000060'));
    expect(authorization, contains('method=md5'));
    expect(authorization, contains('sign='));
  });

  test('reuses imported device token when key is absent and token is valid',
      () {
    const token =
        'version=2018-10-31&res=products%2F5X53hoeOP1%2Fdevices%2Fdon1ng&et=1830268800&method=md5&sign=abc';
    final auth = const OnenetAuth();
    final authorization = auth.generateAuthorization(
      ProjectConfig(
        projectId: '',
        groupId: '',
        accessKey: '',
        productId: '5X53hoeOP1',
        deviceName: 'don1ng',
        deviceToken: token,
        deviceTokenExpiresAt:
            DateTime.fromMillisecondsSinceEpoch(1830268800 * 1000),
      ),
      now: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    expect(authorization, token);
  });

  test('throws readable error for malformed access key', () {
    const auth = OnenetAuth();

    expect(
      () => auth.generateAuthorization(
        const ProjectConfig(
          projectId: 'projectA',
          groupId: 'groupB',
          accessKey: 'not base64',
          productId: 'productC',
          deviceName: 'deviceD',
          authMode: AuthMode.projectGroup,
        ),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('AccessKey 格式错误'),
        ),
      ),
    );
  });
}
