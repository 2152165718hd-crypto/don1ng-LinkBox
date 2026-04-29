import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:don1ng_linkbox/onenet/onenet_api_client.dart';
import 'package:don1ng_linkbox/onenet/onenet_mqtt_service.dart';
import 'package:don1ng_linkbox/runtime/linkbox_controller.dart';
import 'package:don1ng_linkbox/storage/linkbox_repository.dart';
import 'package:don1ng_linkbox/storage/models.dart';
import 'package:don1ng_linkbox/thing_model/thing_model_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = ProjectConfig(
    projectId: 'projectA',
    groupId: 'groupB',
    accessKey: 'dGVzdC1rZXk=',
    productId: 'productC',
    deviceName: 'deviceD',
  );
  const speed = ThingProperty(
    identifier: 'Speed',
    name: '速度',
    type: ThingDataType.int32,
    accessMode: AccessMode.readWrite,
    min: 0,
    max: 100,
    rawType: 'int32',
  );

  test('imports thing model and generates dashboard widgets', () async {
    final repository = _FakeRepository(config: config);
    final controller = LinkBoxController(
      repository: repository,
      importer: _FakeImporter(
        const ThingModelImportResult(
          properties: [speed],
          skipped: [],
          warnings: [],
        ),
      ),
    );
    addTearDown(controller.dispose);

    await controller.init();
    await controller.importThingModel(Uint8List(0));

    expect(controller.state.properties, [speed]);
    expect(
      controller.state.widgets
          .where((item) => item.propertyIdentifier == 'Speed'),
      isNotEmpty,
    );
  });

  test('sendControl validates and dispatches writable values', () async {
    final repository = _FakeRepository(config: config, properties: [speed]);
    final apiClient = _FakeApiClient();
    final controller = LinkBoxController(
      repository: repository,
      apiClient: apiClient,
    );
    addTearDown(controller.dispose);

    await controller.init();
    controller.state = controller.state.copyWith(deviceOnline: true);
    final error = await controller.sendControl(speed, 42);

    expect(error, isNull);
    expect(apiClient.controls, [
      (identifier: 'Speed', value: 42),
    ]);
    expect(repository.cachedValues.single.value, 42);
  });

  test('connectRealtime subscribes after init and records connected state',
      () async {
    final repository = _FakeRepository(config: config);
    final mqttService = _FakeMqttService();
    final controller = LinkBoxController(
      repository: repository,
      mqttService: mqttService,
    );
    addTearDown(controller.dispose);

    await controller.init();
    await controller.connectRealtime();
    await Future<void>.delayed(Duration.zero);

    expect(mqttService.connected, isTrue);
    expect(
      controller.state.connectionState,
      OnenetMqttConnectionState.connected,
    );
  });
}

class _FakeRepository extends LinkBoxRepository {
  _FakeRepository({
    required this.config,
    List<ThingProperty> properties = const [],
  }) : properties = List<ThingProperty>.of(properties);

  ProjectConfig config;
  List<ThingProperty> properties;
  List<DashboardPageConfig> pages = [];
  List<DashboardWidgetConfig> widgets = [];
  List<AppLogEntry> logs = [];
  List<RuntimeValue> cachedValues = [];

  @override
  Future<ProjectConfig> loadConfig() async => config;

  @override
  Future<void> saveConfig(ProjectConfig config) async {
    this.config = config;
  }

  @override
  Future<List<ThingProperty>> loadProperties() async =>
      List<ThingProperty>.of(properties);

  @override
  Future<void> upsertProperties(List<ThingProperty> properties) async {
    final byId = {
      for (final property in this.properties) property.identifier: property,
    };
    for (final property in properties) {
      byId[property.identifier] = property;
    }
    this.properties = byId.values.toList();
  }

  @override
  Future<List<DashboardPageConfig>> loadPages() async =>
      List<DashboardPageConfig>.of(pages);

  @override
  Future<List<DashboardWidgetConfig>> loadWidgets() async =>
      List<DashboardWidgetConfig>.of(widgets);

  @override
  Future<void> savePage(DashboardPageConfig page) async {
    pages = [
      ...pages.where((item) => item.id != page.id),
      page,
    ];
  }

  @override
  Future<void> saveWidgets(List<DashboardWidgetConfig> widgets) async {
    final byId = {
      for (final widget in this.widgets) widget.id: widget,
    };
    for (final widget in widgets) {
      byId[widget.id] = widget;
    }
    this.widgets = byId.values.toList();
  }

  @override
  Future<void> saveWidget(DashboardWidgetConfig widget) async {
    widgets = [
      ...widgets.where((item) => item.id != widget.id),
      widget,
    ];
  }

  @override
  Future<Map<String, RuntimeValue>> latestValues() async => {
        for (final value in cachedValues) value.identifier: value,
      };

  @override
  Future<void> cacheRuntimeValue(
    RuntimeValue value, {
    int retentionDays = 30,
  }) async {
    cachedValues.add(value);
  }

  @override
  Future<List<RuntimeValue>> history({
    required String identifier,
    required DateTime start,
    required DateTime end,
    int limit = 500,
  }) async {
    return cachedValues
        .where((item) => item.identifier == identifier)
        .take(limit)
        .toList();
  }

  @override
  Future<void> addLog(AppLogEntry entry) async {
    logs = [entry, ...logs].take(1000).toList();
  }

  @override
  Future<List<AppLogEntry>> loadLogs({int limit = 200}) async =>
      logs.take(limit).toList();

  @override
  Future<File> exportBackup({required bool includeSecret}) {
    throw UnimplementedError();
  }

  @override
  Future<void> importBackup(Uint8List bytes) {
    throw UnimplementedError();
  }
}

class _FakeImporter extends ThingModelImporter {
  _FakeImporter(this.result);

  final ThingModelImportResult result;

  @override
  Future<ThingModelImportResult> importBytes(Uint8List bytes) async => result;
}

class _FakeApiClient extends OnenetApiClient {
  final controls = <({String identifier, Object? value})>[];

  @override
  Future<void> setDeviceProperty({
    required ProjectConfig config,
    required String identifier,
    required Object? value,
  }) async {
    controls.add((identifier: identifier, value: value));
  }
}

class _FakeMqttService extends OnenetMqttService {
  final _messages = StreamController<OnenetRealtimeMessage>.broadcast();
  final _states = StreamController<OnenetMqttConnectionState>.broadcast();
  bool connected = false;

  @override
  Stream<OnenetRealtimeMessage> get messages => _messages.stream;

  @override
  Stream<OnenetMqttConnectionState> get states => _states.stream;

  @override
  Future<void> connect(ProjectConfig config) async {
    connected = true;
    _states.add(OnenetMqttConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    connected = false;
    _states.add(OnenetMqttConnectionState.disconnected);
  }

  @override
  Future<void> dispose() async {
    await _messages.close();
    await _states.close();
  }
}
