import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../dashboard/dashboard_factory.dart';
import '../onenet/onenet_api_client.dart';
import '../onenet/onenet_mqtt_service.dart';
import '../storage/linkbox_repository.dart';
import '../storage/models.dart';
import '../thing_model/thing_model_importer.dart';
import '../thing_model/validators.dart';

class LinkBoxState {
  const LinkBoxState({
    required this.config,
    required this.properties,
    required this.pages,
    required this.widgets,
    required this.values,
    required this.logs,
    required this.connectionState,
    required this.deviceOnline,
    this.busy = false,
    this.statusText = '',
  });

  final ProjectConfig config;
  final List<ThingProperty> properties;
  final List<DashboardPageConfig> pages;
  final List<DashboardWidgetConfig> widgets;
  final Map<String, RuntimeValue> values;
  final List<AppLogEntry> logs;
  final OnenetMqttConnectionState connectionState;
  final bool deviceOnline;
  final bool busy;
  final String statusText;

  factory LinkBoxState.initial() {
    return LinkBoxState(
      config: ProjectConfig.empty(),
      properties: const [],
      pages: const [],
      widgets: const [],
      values: const {},
      logs: const [],
      connectionState: OnenetMqttConnectionState.disconnected,
      deviceOnline: true,
    );
  }

  LinkBoxState copyWith({
    ProjectConfig? config,
    List<ThingProperty>? properties,
    List<DashboardPageConfig>? pages,
    List<DashboardWidgetConfig>? widgets,
    Map<String, RuntimeValue>? values,
    List<AppLogEntry>? logs,
    OnenetMqttConnectionState? connectionState,
    bool? deviceOnline,
    bool? busy,
    String? statusText,
  }) {
    return LinkBoxState(
      config: config ?? this.config,
      properties: properties ?? this.properties,
      pages: pages ?? this.pages,
      widgets: widgets ?? this.widgets,
      values: values ?? this.values,
      logs: logs ?? this.logs,
      connectionState: connectionState ?? this.connectionState,
      deviceOnline: deviceOnline ?? this.deviceOnline,
      busy: busy ?? this.busy,
      statusText: statusText ?? this.statusText,
    );
  }
}

class LinkBoxController extends ChangeNotifier {
  LinkBoxController({
    LinkBoxRepository? repository,
    OnenetApiClient? apiClient,
    OnenetMqttService? mqttService,
    ThingModelImporter? importer,
    DashboardFactory? dashboardFactory,
    ThingValueValidator? validator,
  })  : _repository = repository ?? LinkBoxRepository(),
        _apiClient = apiClient ?? OnenetApiClient(),
        _mqttService = mqttService ?? OnenetMqttService(),
        _importer = importer ?? ThingModelImporter(),
        _dashboardFactory = dashboardFactory ?? DashboardFactory(),
        _validator = validator ?? const ThingValueValidator() {
    _messageSub = _mqttService.messages.listen(_handleRealtimeMessage);
    _stateSub = _mqttService.states.listen((connectionState) {
      _setState(state.copyWith(connectionState: connectionState));
    });
  }

  final LinkBoxRepository _repository;
  final OnenetApiClient _apiClient;
  final OnenetMqttService _mqttService;
  final ThingModelImporter _importer;
  final DashboardFactory _dashboardFactory;
  final ThingValueValidator _validator;

  late final StreamSubscription<OnenetRealtimeMessage> _messageSub;
  late final StreamSubscription<OnenetMqttConnectionState> _stateSub;
  Timer? _pollTimer;
  LinkBoxState state = LinkBoxState.initial();

  Future<void> init() async {
    _setState(state.copyWith(busy: true, statusText: '正在加载本地配置'));
    await _reloadCoreState(statusText: '本地配置已加载');
  }

  Future<void> saveConfig(ProjectConfig config) async {
    await _repository.saveConfig(config);
    await _log(LogLevel.info, 'config', 'OneNET 配置已保存');
    _setState(
        state.copyWith(config: config, logs: await _repository.loadLogs()));
  }

  Future<ThingModelImportResult> importThingModel(Uint8List bytes) async {
    _setState(state.copyWith(busy: true, statusText: '正在解析物模型'));
    try {
      final result = await _importer.importBytes(bytes);
      await _repository.upsertProperties(result.properties);
      final properties = await _repository.loadProperties();
      await _ensureDashboard(properties);
      await _log(
        LogLevel.info,
        'thing-model',
        '成功导入 ${result.properties.length} 个属性，跳过 ${result.skipped.length} 个',
      );
      await _reloadCoreState(statusText: '物模型导入完成，已生成可编辑 UI 卡片');
      return result;
    } catch (error) {
      await _log(LogLevel.error, 'thing-model', '物模型导入失败',
          detail: error.toString());
      _setState(state.copyWith(busy: false, statusText: '物模型导入失败'));
      rethrow;
    }
  }

  Future<void> regenerateDashboard() async {
    await _ensureDashboard(state.properties);
    await _log(LogLevel.info, 'dashboard', '已补齐默认 UI 卡片和历史曲线');
    await _reloadCoreState(statusText: '默认 UI 已补齐');
  }

  Future<DashboardWidgetConfig?> dataWidgetForProperty(
      ThingProperty property) async {
    final existing = state.widgets.where(
      (widget) =>
          widget.propertyIdentifier == property.identifier &&
          widget.displayMode != DashboardDisplayMode.trendChart,
    );
    if (existing.isNotEmpty) return existing.first;
    await _ensureDashboard(state.properties);
    await _reloadCoreState();
    final created = state.widgets.where(
      (widget) =>
          widget.propertyIdentifier == property.identifier &&
          widget.displayMode != DashboardDisplayMode.trendChart,
    );
    return created.isEmpty ? null : created.first;
  }

  Future<String> saveUploadedIcon({
    required Uint8List bytes,
    required String originalName,
  }) {
    return _repository.saveUploadedIcon(
        bytes: bytes, originalName: originalName);
  }

  Future<void> refreshLatest() async {
    final config = state.config;
    if (!config.isReady) {
      await _log(LogLevel.warning, 'onenet-api', '请先填写完整 OneNET 配置');
      await _reloadLogs();
      return;
    }
    _setState(state.copyWith(busy: true, statusText: '正在同步最新属性'));
    try {
      final latest = await _apiClient.queryLatest(config);
      final values = Map<String, RuntimeValue>.of(state.values);
      for (final value in latest) {
        values[value.identifier] = value;
        await _repository.cacheRuntimeValue(value);
      }
      await _log(LogLevel.info, 'onenet-api', '已同步 ${latest.length} 个最新属性');
      _setState(
        state.copyWith(
          values: values,
          logs: await _repository.loadLogs(),
          busy: false,
          statusText: '最新属性已同步',
        ),
      );
    } catch (error) {
      await _log(LogLevel.error, 'onenet-api', '最新属性同步失败',
          detail: error.toString());
      _setState(state.copyWith(
          busy: false, logs: await _repository.loadLogs(), statusText: '同步失败'));
    }
  }

  Future<void> connectRealtime() async {
    final config = state.config;
    if (!config.isReady) {
      await _log(LogLevel.warning, 'mqtt', '请先填写完整 OneNET 配置');
      await _reloadLogs();
      return;
    }
    try {
      await _mqttService.connect(config);
      _startPollingFallback();
      await _log(LogLevel.info, 'mqtt', '应用长连接已启动');
      await _reloadLogs();
    } catch (error) {
      _startPollingFallback();
      await _log(LogLevel.error, 'mqtt', '应用长连接失败，已启用 API 轮询',
          detail: error.toString());
      await _reloadLogs();
    }
  }

  Future<void> disconnectRealtime() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await _mqttService.disconnect();
    await _log(LogLevel.info, 'mqtt', '应用长连接已断开');
    await _reloadLogs();
  }

  Future<String?> sendControl(ThingProperty property, Object? rawValue) async {
    if (!state.deviceOnline) {
      return '设备离线，已拦截控制指令';
    }
    final validation = _validator.validateForControl(property, rawValue);
    if (!validation.isValid) return validation.message;
    try {
      await _apiClient.setDeviceProperty(
        config: state.config,
        identifier: property.identifier,
        value: validation.value,
      );
      final runtimeValue = RuntimeValue(
        identifier: property.identifier,
        value: validation.value,
        time: DateTime.now(),
      );
      await _repository.cacheRuntimeValue(runtimeValue);
      await _log(LogLevel.info, 'control', '${property.displayName} 控制指令已下发');
      final values = Map<String, RuntimeValue>.of(state.values);
      values[property.identifier] = runtimeValue;
      _setState(
          state.copyWith(values: values, logs: await _repository.loadLogs()));
      return null;
    } catch (error) {
      await _log(LogLevel.error, 'control', '${property.displayName} 控制失败',
          detail: error.toString());
      await _reloadLogs();
      return error.toString();
    }
  }

  Future<List<RuntimeValue>> loadHistory(ThingProperty property) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: state.config.historyDays));
    if (!state.config.isReady) {
      return _repository.history(
          identifier: property.identifier, start: start, end: now);
    }
    try {
      final remote = await _apiClient.queryHistory(
        config: state.config,
        identifier: property.identifier,
        start: start,
        end: now,
        limit: 100,
      );
      for (final value in remote) {
        await _repository.cacheRuntimeValue(value);
      }
      return remote;
    } catch (_) {
      return _repository.history(
          identifier: property.identifier, start: start, end: now);
    }
  }

  Future<File> exportBackup({bool includeSecret = false}) async {
    final file = await _repository.exportBackup(includeSecret: includeSecret);
    await _log(LogLevel.info, 'backup', '配置已导出 ${file.path}');
    await _reloadLogs();
    return file;
  }

  Future<void> updateWidget(DashboardWidgetConfig widget) async {
    await _repository.saveWidget(widget);
    final widgets = await _repository.loadWidgets();
    _setState(state.copyWith(widgets: widgets));
  }

  Future<void> deleteWidget(String id) async {
    await _repository.deleteWidget(id);
    final widgets = await _repository.loadWidgets();
    await _log(LogLevel.info, 'dashboard', '控件已删除');
    _setState(
        state.copyWith(widgets: widgets, logs: await _repository.loadLogs()));
  }

  Future<void> _ensureDashboard(List<ThingProperty> properties) async {
    final pages = await _repository.loadPages();
    final widgets = await _repository.loadWidgets();
    final dashboard = _dashboardFactory.mergeForProperties(
      properties: properties,
      pages: pages,
      widgets: widgets,
    );
    for (final page in dashboard.pages) {
      await _repository.savePage(page);
    }
    await _repository.saveWidgets(dashboard.widgets);
  }

  Future<void> _reloadCoreState({String statusText = ''}) async {
    _setState(
      state.copyWith(
        config: await _repository.loadConfig(),
        properties: await _repository.loadProperties(),
        pages: await _repository.loadPages(),
        widgets: await _repository.loadWidgets(),
        values: await _repository.latestValues(),
        logs: await _repository.loadLogs(),
        busy: false,
        statusText: statusText,
      ),
    );
  }

  Future<void> _reloadLogs() async {
    _setState(state.copyWith(logs: await _repository.loadLogs()));
  }

  Future<void> _log(LogLevel level, String type, String message,
      {String detail = ''}) async {
    await _repository.addLog(
      AppLogEntry(
        time: DateTime.now(),
        level: level,
        type: type,
        message: message,
        detail: detail,
      ),
    );
  }

  void _handleRealtimeMessage(OnenetRealtimeMessage message) async {
    if (message.type == OnenetRealtimeMessageType.lifecycle) {
      final data = message.payload['data'];
      final status = data is Map ? data['status']?.toString() : null;
      _setState(state.copyWith(deviceOnline: status != 'offline'));
      await _log(LogLevel.info, 'lifecycle', '设备状态 ${status ?? 'unknown'}');
      await _reloadLogs();
      return;
    }
    final runtimeValues = message.toRuntimeValues();
    if (runtimeValues.isEmpty) return;
    final values = Map<String, RuntimeValue>.of(state.values);
    for (final entry in runtimeValues.entries) {
      values[entry.key] = entry.value;
      await _repository.cacheRuntimeValue(entry.value);
    }
    await _log(LogLevel.info, 'mqtt', '收到 ${runtimeValues.length} 个实时属性');
    _setState(
        state.copyWith(values: values, logs: await _repository.loadLogs()));
  }

  void _startPollingFallback() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: state.config.refreshSeconds.clamp(5, 3600).toInt()),
      (_) {
        if (state.connectionState != OnenetMqttConnectionState.connected) {
          refreshLatest();
        }
      },
    );
  }

  void _setState(LinkBoxState next) {
    state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageSub.cancel();
    _stateSub.cancel();
    _mqttService.dispose();
    super.dispose();
  }
}
