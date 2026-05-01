import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../storage/models.dart';
import 'onenet_auth.dart';

enum OnenetMqttConnectionState { disconnected, connecting, connected, failed }

enum OnenetRealtimeMessageType {
  lifecycle,
  property,
  event,
  propertySet,
  propertySetReply,
  unknown
}

class OnenetMqttCredentials {
  const OnenetMqttCredentials({
    required this.clientId,
    required this.username,
    required this.password,
    required this.usesDeviceToken,
  });

  final String clientId;
  final String username;
  final String password;
  final bool usesDeviceToken;
}

class OnenetMqttEndpoint {
  const OnenetMqttEndpoint({
    required this.host,
    required this.port,
    required this.secure,
  });

  final String host;
  final int port;
  final bool secure;
}

class OnenetRealtimeMessage {
  const OnenetRealtimeMessage({
    required this.type,
    required this.topic,
    required this.receivedAt,
    required this.payload,
  });

  final OnenetRealtimeMessageType type;
  final String topic;
  final DateTime receivedAt;
  final Map<String, Object?> payload;

  Map<String, RuntimeValue> toRuntimeValues() {
    if (type != OnenetRealtimeMessageType.property &&
        type != OnenetRealtimeMessageType.propertySet) {
      return const {};
    }
    final data = payload['data'];
    final params = data is Map ? data['params'] : payload['params'];
    if (params is! Map) return const {};
    final values = <String, RuntimeValue>{};
    for (final entry in params.entries) {
      final identifier = entry.key.toString();
      final node = entry.value;
      if (node is Map) {
        values[identifier] = RuntimeValue(
          identifier: identifier,
          value: node['value'],
          time: _parseMillis(node['time']),
        );
      } else {
        values[identifier] = RuntimeValue(
          identifier: identifier,
          value: node,
          time: receivedAt,
        );
      }
    }
    return values;
  }

  static DateTime _parseMillis(Object? raw) {
    final millis = int.tryParse(raw?.toString() ?? '');
    if (millis == null) return DateTime.now();
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}

class OnenetMqttService {
  OnenetMqttService({
    OnenetAuth? auth,
  }) : _auth = auth ?? const OnenetAuth();

  static const _mqttHost = 'studio-mqtt.heclouds.com';
  static const _mqttTlsHost = 'studio-mqtts.heclouds.com';
  static const _mqttPort = 1883;
  static const _mqttTlsPort = 8883;

  final OnenetAuth _auth;
  final _messages = StreamController<OnenetRealtimeMessage>.broadcast();
  final _states = StreamController<OnenetMqttConnectionState>.broadcast();
  MqttServerClient? _client;

  Stream<OnenetRealtimeMessage> get messages => _messages.stream;
  Stream<OnenetMqttConnectionState> get states => _states.stream;

  OnenetMqttEndpoint endpointFor(ProjectConfig config) {
    if (config.mqttUseTls) {
      return const OnenetMqttEndpoint(
        host: _mqttTlsHost,
        port: _mqttTlsPort,
        secure: true,
      );
    }
    return const OnenetMqttEndpoint(
      host: _mqttHost,
      port: _mqttPort,
      secure: false,
    );
  }

  OnenetMqttCredentials credentialsFor(ProjectConfig config, {DateTime? now}) {
    if (config.authMode == AuthMode.deviceToken) {
      return OnenetMqttCredentials(
        clientId: config.deviceName.trim(),
        username: config.productId.trim(),
        password: _auth.generateDeviceToken(config, now: now),
        usesDeviceToken: true,
      );
    }
    final effectiveNow = now ?? DateTime.now();
    return OnenetMqttCredentials(
      clientId: 'don1ng_linkbox_${effectiveNow.millisecondsSinceEpoch}',
      username: config.resource,
      password: _auth.generateApplicationAuthorization(config, now: now),
      usesDeviceToken: false,
    );
  }

  Future<void> connect(ProjectConfig config) async {
    await disconnect();
    _states.add(OnenetMqttConnectionState.connecting);
    final credentials = credentialsFor(config);
    final endpoint = endpointFor(config);
    final client = MqttServerClient.withPort(
      endpoint.host,
      credentials.clientId,
      endpoint.port,
    );
    client.secure = endpoint.secure;
    client.keepAlivePeriod = 60;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.logging(on: false);
    client.onConnected = () {
      _states.add(OnenetMqttConnectionState.connected);
      _subscribe(config);
    };
    client.onDisconnected = () {
      _states.add(OnenetMqttConnectionState.disconnected);
    };
    client.onAutoReconnect =
        () => _states.add(OnenetMqttConnectionState.connecting);
    client.onAutoReconnected =
        () => _states.add(OnenetMqttConnectionState.connected);
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(credentials.clientId)
        .authenticateAs(credentials.username, credentials.password)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    _client = client;
    try {
      await client.connect();
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        throw StateError('MQTT 连接失败: ${client.connectionStatus?.returnCode}');
      }
      client.updates?.listen(_handleUpdates);
    } catch (_) {
      _states.add(OnenetMqttConnectionState.failed);
      client.disconnect();
      _client = null;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _client?.disconnect();
    _client = null;
    _states.add(OnenetMqttConnectionState.disconnected);
  }

  Future<void> publishProperty({
    required ProjectConfig config,
    required String identifier,
    required Object? value,
  }) async {
    final client = _client;
    if (client == null ||
        client.connectionStatus?.state != MqttConnectionState.connected) {
      throw StateError('MQTT 未连接，无法发布属性');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      'id': now.toString(),
      'version': '1.0',
      'params': {
        identifier: {
          'value': value,
          'time': now,
        },
      },
    };
    final builder = MqttClientPayloadBuilder();
    builder.addUTF8String(jsonEncode(payload));
    client.publishMessage(
      '\$sys/${config.productId}/${config.deviceName}/thing/property/post',
      MqttQos.atMostOnce,
      builder.payload!,
    );
  }

  void _subscribe(ProjectConfig config) {
    final base = '\$sys/${config.productId}/${config.deviceName}/thing';
    _client?.subscribe('$base/lifecycle', MqttQos.atMostOnce);
    _client?.subscribe('$base/property', MqttQos.atMostOnce);
    _client?.subscribe('$base/property/post/reply', MqttQos.atMostOnce);
    _client?.subscribe('$base/property/set', MqttQos.atMostOnce);
    _client?.subscribe('$base/property/set/reply', MqttQos.atMostOnce);
    _client?.subscribe('$base/event', MqttQos.atMostOnce);
  }

  void _handleUpdates(List<MqttReceivedMessage<MqttMessage>> updates) {
    for (final update in updates) {
      final message = update.payload;
      if (message is! MqttPublishMessage) continue;
      final payloadText =
          MqttPublishPayload.bytesToStringAsString(message.payload.message);
      final decoded = _decodePayload(payloadText);
      _messages.add(
        OnenetRealtimeMessage(
          type: _typeFromTopic(update.topic),
          topic: update.topic,
          receivedAt: DateTime.now(),
          payload: decoded,
        ),
      );
    }
  }

  Map<String, Object?> _decodePayload(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } on FormatException {
      return {'raw': text};
    }
    return {'raw': text};
  }

  OnenetRealtimeMessageType _typeFromTopic(String topic) {
    if (topic.endsWith('/thing/lifecycle')) {
      return OnenetRealtimeMessageType.lifecycle;
    }
    if (topic.endsWith('/thing/property') ||
        topic.endsWith('/thing/property/post')) {
      return OnenetRealtimeMessageType.property;
    }
    if (topic.endsWith('/thing/property/set')) {
      return OnenetRealtimeMessageType.propertySet;
    }
    if (topic.endsWith('/thing/event')) return OnenetRealtimeMessageType.event;
    if (topic.endsWith('/thing/property/set/reply')) {
      return OnenetRealtimeMessageType.propertySetReply;
    }
    return OnenetRealtimeMessageType.unknown;
  }

  Future<void> dispose() async {
    await disconnect();
    await _messages.close();
    await _states.close();
  }
}
