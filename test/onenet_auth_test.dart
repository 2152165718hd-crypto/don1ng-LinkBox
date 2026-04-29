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
      ),
      now: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    expect(authorization, contains('version=2020-05-29'));
    expect(authorization, contains('res=projectid%2FprojectA%2Fgroupid%2FgroupB'));
    expect(authorization, contains('et=1700000060'));
    expect(authorization, contains('method=sha1'));
    expect(authorization, contains('sign='));
  });
}
