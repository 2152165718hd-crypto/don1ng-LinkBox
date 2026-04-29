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
  propertySetReply,
  unknown
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
    if (type != OnenetRealtimeMessageType.property) return const {};
    final data = payload['data'];
    if (data is! Map) return const {};
    final params = data['params'];
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

  final OnenetAuth _auth;
  final _messages = StreamController<OnenetRealtimeMessage>.broadcast();
  final _states = StreamController<OnenetMqttConnectionState>.broadcast();
  MqttServerClient? _client;

  Stream<OnenetRealtimeMessage> get messages => _messages.stream;
  Stream<OnenetMqttConnectionState> get states => _states.stream;

  Future<void> connect(ProjectConfig config) async {
    await disconnect();
    _states.add(OnenetMqttConnectionState.connecting);
    final clientId = 'don1ng_linkbox_${DateTime.now().millisecondsSinceEpoch}';
    final client =
        MqttServerClient.withPort('183.230.102.116', clientId, 25002);
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
        .withClientIdentifier(clientId)
        .authenticateAs(config.resource, _auth.generateAuthorization(config))
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

  void _subscribe(ProjectConfig config) {
    final base = '\$sys/${config.productId}/${config.deviceName}/thing';
    _client?.subscribe('$base/lifecycle', MqttQos.atMostOnce);
    _client?.subscribe('$base/property', MqttQos.atMostOnce);
    _client?.subscribe('$base/event', MqttQos.atMostOnce);
    _client?.subscribe('$base/property/set/reply', MqttQos.atMostOnce);
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
    if (topic.endsWith('/thing/property')) {
      return OnenetRealtimeMessageType.property;
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
