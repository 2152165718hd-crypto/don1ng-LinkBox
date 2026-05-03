import 'dart:async';
import 'dart:convert';
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
    authMode: AuthMode.projectGroup,
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
  const mainPage = DashboardPageConfig(id: 'main', name: '主面板');
  const speedWidget = DashboardWidgetConfig(
    id: 'speed_card',
    pageId: 'main',
    type: DashboardWidgetType.valueCard,
    propertyIdentifier: 'Speed',
    title: '速度',
    x: 0,
    y: 0,
    width: 180,
    height: 110,
    displayMode: DashboardDisplayMode.value,
  );

  test('imports thing model and generates realtime dashboard widgets',
      () async {
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
      controller.state.widgets.where((item) =>
          item.propertyIdentifier == 'Speed' &&
          item.displayMode != DashboardDisplayMode.trendChart),
      isNotEmpty,
    );
    expect(
      controller.state.widgets
          .where((item) => item.displayMode == DashboardDisplayMode.trendChart),
      isEmpty,
    );
  });

  test('init removes legacy trend widgets from local dashboard state',
      () async {
    final repository = _FakeRepository(
      config: config,
      properties: [speed],
      pages: [mainPage],
      widgets: [
        speedWidget,
        const DashboardWidgetConfig(
          id: 'speed_trend',
          pageId: 'main',
          type: DashboardWidgetType.trendChart,
          propertyIdentifier: 'Speed',
          title: '速度趋势',
          x: 0,
          y: 128,
          width: 360,
          height: 210,
          displayMode: DashboardDisplayMode.trendChart,
        ),
      ],
    );
    final controller = LinkBoxController(repository: repository);
    addTearDown(controller.dispose);

    await controller.init();

    expect(
      controller.state.widgets
          .where((item) => item.displayMode == DashboardDisplayMode.trendChart),
      isEmpty,
    );
    expect(
      repository.widgets
          .where((item) => item.displayMode == DashboardDisplayMode.trendChart),
      isEmpty,
    );
  });

  test('imports Token.log as ready simple connection', () async {
    final repository = _FakeRepository(config: ProjectConfig.empty());
    final controller = LinkBoxController(repository: repository);
    addTearDown(controller.dispose);

    await controller.init();
    final config = await controller.importTokenLog(
      ConnectionImportFile(
        name: 'Token.log',
        bytes: Uint8List.fromList(utf8.encode(_tokenLogText)),
      ),
    );

    expect(config.authMode, AuthMode.deviceToken);
    expect(config.mqttUseTls, isFalse);
    expect(controller.state.config.isReady, isTrue);
    expect(controller.state.config.mqttUseTls, isFalse);
    expect(controller.state.config.productId, '5X53hoeOP1');
    expect(controller.state.config.deviceName, 'don1ng');
    expect(controller.state.properties, isEmpty);
    expect(controller.state.widgets, isEmpty);
  });

  test('rejects thing model import when product ids do not match', () async {
    final repository = _FakeRepository(config: ProjectConfig.empty());
    final controller = LinkBoxController(repository: repository);
    addTearDown(controller.dispose);

    await controller.init();
    await controller.importTokenLog(
      ConnectionImportFile(
        name: 'Token.log',
        bytes: Uint8List.fromList(utf8.encode(_tokenLogText)),
      ),
    );

    expect(
      () => controller.importThingModel(
        Uint8List.fromList(utf8.encode(_thingModelJson('other'))),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Product ID'),
        ),
      ),
    );
  });

  test('clears thing model dashboard and local runtime values', () async {
    final repository = _FakeRepository(
      config: config,
      properties: [speed],
      pages: [mainPage],
      widgets: [speedWidget],
      cachedValues: [
        RuntimeValue(identifier: 'Speed', value: 42, time: DateTime.now()),
      ],
    );
    final controller = LinkBoxController(repository: repository);
    addTearDown(controller.dispose);

    await controller.init();
    expect(controller.state.properties, isNotEmpty);
    expect(controller.state.pages, isNotEmpty);
    expect(controller.state.widgets, isNotEmpty);
    expect(controller.state.values, isNotEmpty);

    await controller.clearThingModel();

    expect(controller.state.properties, isEmpty);
    expect(controller.state.pages, isEmpty);
    expect(controller.state.widgets, isEmpty);
    expect(controller.state.values, isEmpty);
    expect(repository.cachedValues, isEmpty);
  });

  test('clearThingModel disconnects MQTT and stops polling fallback', () async {
    final repository = _FakeRepository(
      config: config,
      properties: [speed],
      pages: [mainPage],
      widgets: [speedWidget],
    );
    final mqttService = _FakeMqttService();
    final controller = LinkBoxController(
      repository: repository,
      mqttService: mqttService,
    );
    addTearDown(controller.dispose);

    await controller.init();
    await controller.connectRealtime();
    await Future<void>.delayed(Duration.zero);
    expect(controller.pollingFallbackActive, isTrue);
    expect(mqttService.connected, isTrue);

    await controller.clearThingModel();

    expect(controller.pollingFallbackActive, isFalse);
    expect(mqttService.disconnectCalls, 1);
    expect(mqttService.connected, isFalse);
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

  test('sendControl publishes property through MQTT in simple mode', () async {
    const simpleConfig = ProjectConfig(
      projectId: '',
      groupId: '',
      accessKey: '',
      productId: '5X53hoeOP1',
      deviceName: 'don1ng',
      deviceKey: 'RHN5YlNhV3FiemVDNDBrNFBseWF4WXB5UzJZMnJlekg=',
    );
    final repository =
        _FakeRepository(config: simpleConfig, properties: [speed]);
    final mqttService = _FakeMqttService();
    final controller = LinkBoxController(
      repository: repository,
      mqttService: mqttService,
    );
    addTearDown(controller.dispose);

    await controller.init();
    controller.state = controller.state.copyWith(deviceOnline: true);
    final error = await controller.sendControl(speed, 42);

    expect(error, isNull);
    expect(mqttService.published, [
      (identifier: 'Speed', value: 42),
    ]);
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

  test('connectRealtime returns missing-field diagnostics', () async {
    final repository = _FakeRepository(config: ProjectConfig.empty());
    final controller = LinkBoxController(repository: repository);
    addTearDown(controller.dispose);

    await controller.init();
    final failure = await controller.connectRealtime();

    expect(failure, isNotNull);
    expect(failure!.field, contains('Product ID'));
    expect(failure.field, contains('Device Name'));
    expect(failure.field, contains('Device Key 或 Token'));
    expect(failure.suggestion, contains('Token.log'));
  });

  test('connectRealtime returns actionable diagnostics when MQTT rejects login',
      () async {
    const simpleConfig = ProjectConfig(
      projectId: '',
      groupId: '',
      accessKey: '',
      productId: '5X53hoeOP1',
      deviceName: 'don1ng',
      deviceToken: 'version=2018-10-31&sign=bad',
    );
    final repository = _FakeRepository(config: simpleConfig);
    final mqttService = _FailingMqttService(
      StateError('MQTT 连接失败: badUsernameOrPassword'),
    );
    final controller = LinkBoxController(
      repository: repository,
      mqttService: mqttService,
    );
    addTearDown(controller.dispose);

    await controller.init();
    final failure = await controller.connectRealtime();

    expect(failure, isNotNull);
    expect(failure!.field, contains('Token'));
    expect(failure.reason, contains('OneNET 拒绝'));
    expect(failure.suggestion, contains('重新导入 Token.log'));
    expect(controller.state.connectionState, OnenetMqttConnectionState.failed);
  });
}

const _tokenLogText = '''
res：products/5X53hoeOP1/devices/don1ng
et：1830268800
key：RHN5YlNhV3FiemVDNDBrNFBseWF4WXB5UzJZMnJlekg=
method:md5
version:2018-10-31
Token：version=2018-10-31&res=products%2F5X53hoeOP1%2Fdevices%2Fdon1ng&et=1830268800&method=md5&sign=abc
''';

String _thingModelJson(String productId) => '''
{
  "version": "1.0",
  "profile": {
    "productId": "$productId"
  },
  "properties": [
    {
      "identifier": "Speed",
      "name": "速度",
      "accessMode": "rw",
      "dataType": {
        "type": "int32",
        "specs": {
          "min": "0",
          "max": "100",
          "step": "1"
        }
      }
    }
  ]
}
''';

class _FakeRepository extends LinkBoxRepository {
  _FakeRepository({
    required this.config,
    List<ThingProperty> properties = const [],
    List<DashboardPageConfig> pages = const [],
    List<DashboardWidgetConfig> widgets = const [],
    List<RuntimeValue> cachedValues = const [],
  })  : properties = List<ThingProperty>.of(properties),
        pages = List<DashboardPageConfig>.of(pages),
        widgets = List<DashboardWidgetConfig>.of(widgets),
        cachedValues = List<RuntimeValue>.of(cachedValues);

  ProjectConfig config;
  List<ThingProperty> properties;
  List<DashboardPageConfig> pages;
  List<DashboardWidgetConfig> widgets;
  List<AppLogEntry> logs = [];
  List<RuntimeValue> cachedValues;

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
  Future<void> clearThingModel() async {
    properties = [];
    pages = [];
    widgets = [];
    cachedValues = [];
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
  Future<void> replaceDashboard({
    required List<DashboardPageConfig> pages,
    required List<DashboardWidgetConfig> widgets,
  }) async {
    this.pages = List<DashboardPageConfig>.of(pages);
    this.widgets = List<DashboardWidgetConfig>.of(widgets);
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
  final published = <({String identifier, Object? value})>[];
  bool connected = false;
  int disconnectCalls = 0;

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
    disconnectCalls += 1;
    connected = false;
    _states.add(OnenetMqttConnectionState.disconnected);
  }

  @override
  Future<void> publishProperty({
    required ProjectConfig config,
    required String identifier,
    required Object? value,
  }) async {
    published.add((identifier: identifier, value: value));
  }

  @override
  Future<void> dispose() async {
    await _messages.close();
    await _states.close();
  }
}

class _FailingMqttService extends _FakeMqttService {
  _FailingMqttService(this.error);

  final Object error;

  @override
  Future<void> connect(ProjectConfig config) async {
    throw error;
  }
}
