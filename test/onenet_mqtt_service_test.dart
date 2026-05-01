import 'package:don1ng_linkbox/onenet/onenet_mqtt_service.dart';
import 'package:don1ng_linkbox/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default endpoint uses non encrypted MQTT', () {
    final service = OnenetMqttService();
    final endpoint = service.endpointFor(
      const ProjectConfig(
        projectId: '',
        groupId: '',
        accessKey: '',
        productId: '5X53hoeOP1',
        deviceName: 'don1ng',
      ),
    );

    expect(endpoint.host, 'studio-mqtt.heclouds.com');
    expect(endpoint.port, 1883);
    expect(endpoint.secure, isFalse);
  });

  test('TLS endpoint uses encrypted MQTT', () {
    final service = OnenetMqttService();
    final endpoint = service.endpointFor(
      const ProjectConfig(
        projectId: '',
        groupId: '',
        accessKey: '',
        productId: '5X53hoeOP1',
        deviceName: 'don1ng',
        mqttUseTls: true,
      ),
    );

    expect(endpoint.host, 'studio-mqtts.heclouds.com');
    expect(endpoint.port, 8883);
    expect(endpoint.secure, isTrue);
  });

  test('device token mode uses device MQTT identity', () {
    final service = OnenetMqttService();
    final credentials = service.credentialsFor(
      const ProjectConfig(
        projectId: '',
        groupId: '',
        accessKey: '',
        productId: '5X53hoeOP1',
        deviceName: 'don1ng',
        deviceKey: 'RHN5YlNhV3FiemVDNDBrNFBseWF4WXB5UzJZMnJlekg=',
      ),
      now: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

    expect(credentials.clientId, 'don1ng');
    expect(credentials.username, '5X53hoeOP1');
    expect(credentials.password,
        contains('res=products%2F5X53hoeOP1%2Fdevices%2Fdon1ng'));
    expect(credentials.usesDeviceToken, isTrue);
  });

  test('advanced mode keeps application authorization identity', () {
    final service = OnenetMqttService();
    final credentials = service.credentialsFor(
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

    expect(credentials.clientId, 'don1ng_linkbox_1700000000000');
    expect(credentials.username, 'projectid/projectA/groupid/groupB');
    expect(credentials.password,
        contains('res=projectid%2FprojectA%2Fgroupid%2FgroupB'));
    expect(credentials.usesDeviceToken, isFalse);
  });

  test('connection message pins MQTT 3.1.1 for OneNET', () {
    final service = OnenetMqttService();
    final message = service.createConnectionMessage(
      const OnenetMqttCredentials(
        clientId: 'clientA',
        username: 'userB',
        password: 'passC',
        usesDeviceToken: true,
      ),
    );

    expect(message.variableHeader?.protocolName, 'MQTT');
    expect(message.variableHeader?.protocolVersion, 4);
    expect(message.payload.clientIdentifier, 'clientA');
    expect(message.payload.username, 'userB');
    expect(message.payload.password, 'passC');
  });
}
