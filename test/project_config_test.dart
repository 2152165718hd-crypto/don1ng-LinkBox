import 'package:don1ng_linkbox/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project config defaults MQTT TLS off and round trips the setting', () {
    expect(ProjectConfig.empty().mqttUseTls, isFalse);

    const config = ProjectConfig(
      projectId: 'projectA',
      groupId: 'groupB',
      accessKey: 'accessKey',
      productId: 'productC',
      deviceName: 'deviceD',
      mqttUseTls: true,
    );

    final dbMap = config.toDbMap(includeSecret: true);
    expect(dbMap['mqtt_use_tls'], 1);
    expect(
      ProjectConfig.fromMap(
        dbMap,
        accessKey: 'accessKey',
      ).mqttUseTls,
      isTrue,
    );

    final exportMap = config.toExportMap(includeSecret: true);
    expect(exportMap['mqtt_use_tls'], isTrue);
    expect(
      ProjectConfig.fromMap(
        exportMap,
        accessKey: 'accessKey',
      ).mqttUseTls,
      isTrue,
    );

    expect(
      ProjectConfig.fromMap({
        'project_id': 'projectA',
        'group_id': 'groupB',
        'product_id': 'productC',
        'device_name': 'deviceD',
      }).mqttUseTls,
      isFalse,
    );
  });
}
