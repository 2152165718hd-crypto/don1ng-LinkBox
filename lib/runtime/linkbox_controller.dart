import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../dashboard/dashboard_factory.dart';
import '../onenet/onenet_api_client.dart';
import '../onenet/onenet_mqtt_service.dart';
import '../onenet/token_log_parser.dart';
import '../storage/linkbox_repository.dart';
import '../storage/models.dart';
import '../thing_model/thing_model_importer.dart';
import '../thing_model/validators.dart';

class ConnectionImportFile {
  const ConnectionImportFile({
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;
}

class ConnectionImportResult {
  const ConnectionImportResult({
    required this.config,
    required this.thingModel,
  });

  final ProjectConfig config;
  final ThingModelImportResult thingModel;
}

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
      deviceOnline: false,
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
        _validator = validator ?? const ThingValueValidator();

  final LinkBoxRepository _repository;
  final OnenetApiClient _apiClient;
  final OnenetMqttService _mqttService;
  final ThingModelImporter _importer;
  final DashboardFactory _dashboardFactory;
  final ThingValueValidator _validator;

  StreamSubscription<OnenetRealtimeMessage>? _messageSub;
  StreamSubscription<OnenetMqttConnectionState>? _stateSub;
  Timer? _pollTimer;
  Future<void>? _initFuture;
  bool _initialized = false;
  LinkBoxState state = LinkBoxState.initial();

  Future<void> init() async {
    _initFuture ??= _init();
    await _initFuture;
  }

  Future<void> _init() async {
    _setState(state.copyWith(busy: true, statusText: '正在加载本地配置'));
    await _reloadCoreState(statusText: '本地配置已加载');
    _initialized = true;
    _ensureSubscriptions();
  }

  void _ensureSubscriptions() {
    _messageSub ??= _mqttService.messages.listen(_handleRealtimeMessage);
    _stateSub ??= _mqttService.states.listen(_handleConnectionState);
  }

  void _handleConnectionState(OnenetMqttConnectionState connectionState) {
    final deviceOnline = switch (connectionState) {
      OnenetMqttConnectionState.connected => state.deviceOnline,
      OnenetMqttConnectionState.connecting ||
      OnenetMqttConnectionState.disconnected ||
      OnenetMqttConnectionState.failed =>
        false,
    };
    _setState(state.copyWith(
      connectionState: connectionState,
      deviceOnline: deviceOnline,
    ));
  }

  Future<void> saveConfig(ProjectConfig config) async {
    await _repository.saveConfig(config);
    await _log(LogLevel.info, 'config', 'OneNET 配置已保存');
    _setState(
        state.copyWith(config: config, logs: await _repository.loadLogs()));
  }

  Future<ConnectionImportResult> importConnectionFiles(
      List<ConnectionImportFile> files) async {
    if (files.isEmpty) {
      throw const FormatException('请选择 Token.log 和物模型 JSON');
    }
    _setState(state.copyWith(busy: true, statusText: '正在导入连接文件'));
    try {
      TokenLogInfo? tokenInfo;
      ThingModelImportResult? thingModel;
      for (final file in files) {
        if (_looksLikeJson(file)) {
          thingModel = await _importer.importBytes(file.bytes);
          continue;
        }
        tokenInfo = await TokenLogParser().parseBytes(file.bytes);
      }
      if (tokenInfo == null) {
        throw const FormatException('未找到 Token.log 文件');
      }
      if (thingModel == null) {
        throw const FormatException('未找到物模型 JSON 文件');
      }
      _ensureProductIdsMatch(tokenInfo.productId, thingModel.productId);
      final config = _configFromTokenInfo(tokenInfo);
      await _repository.saveConfig(config);
      await _repository.upsertProperties(thingModel.properties);
      final properties = await _repository.loadProperties();
      await _ensureDashboard(properties);
      await _log(
        LogLevel.info,
        'connection-import',
        '已导入 Token.log 和物模型，生成 ${thingModel.properties.length} 个属性',
      );
      await _reloadCoreState(statusText: '连接文件导入完成，可直接点击连接');
      return ConnectionImportResult(config: config, thingModel: thingModel);
    } catch (error) {
      await _log(LogLevel.error, 'connection-import', '连接文件导入失败',
          detail: error.toString());
      _setState(state.copyWith(
        busy: false,
        logs: await _repository.loadLogs(),
        statusText: '连接文件导入失败',
      ));
      rethrow;
    }
  }

  Future<ThingModelImportResult> importThingModel(Uint8List bytes) async {
    _setState(state.copyWith(busy: true, statusText: '正在解析物模型'));
    try {
      final result = await _importer.importBytes(bytes);
      final config = state.config;
      if (config.productId.trim().isNotEmpty && result.productId.isNotEmpty) {
        _ensureProductIdsMatch(config.productId, result.productId);
      }
      if (config.productId.trim().isEmpty && result.productId.isNotEmpty) {
        await _repository
            .saveConfig(config.copyWith(productId: result.productId));
      }
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

  Future<void> clearThingModel() async {
    _setState(state.copyWith(busy: true, statusText: '正在删除物模型'));
    try {
      _pollTimer?.cancel();
      _pollTimer = null;
      await _mqttService.disconnect();
      await _repository.clearThingModel();
      await _log(LogLevel.info, 'thing-model', '物模型、面板和本地历史已删除');
      await _reloadCoreState(statusText: '物模型已删除，可导入新的设备物模型');
    } catch (error) {
      await _log(LogLevel.error, 'thing-model', '物模型删除失败',
          detail: error.toString());
      _setState(state.copyWith(
        busy: false,
        logs: await _repository.loadLogs(),
        statusText: '物模型删除失败',
      ));
      rethrow;
    }
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
    if (!config.supportsOpenApi) {
      final values = await _repository.latestValues();
      await _log(LogLevel.info, 'mqtt', '简单模式使用 MQTT 实时数据，已刷新本地缓存');
      _setState(state.copyWith(
        values: values,
        logs: await _repository.loadLogs(),
        busy: false,
        statusText: '已刷新本地缓存',
      ));
      return;
    }
    _setState(state.copyWith(busy: true, statusText: '正在同步最新属性'));
    try {
      final latest = await _apiClient.queryLatest(config);
      final values = Map<String, RuntimeValue>.of(state.values);
      for (final value in latest) {
        values[value.identifier] = value;
        await _repository.cacheRuntimeValue(
          value,
          retentionDays: _runtimeRetentionDays,
        );
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
      if (config.supportsOpenApi) {
        _startPollingFallback();
      } else {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
      await _log(
        LogLevel.info,
        'mqtt',
        config.usesDeviceToken ? '设备 Token MQTT 已启动' : '应用长连接已启动',
      );
      await _reloadLogs();
    } catch (error) {
      if (config.supportsOpenApi) {
        _startPollingFallback();
      }
      await _log(LogLevel.error, 'mqtt', 'MQTT 连接失败', detail: error.toString());
      await _reloadLogs();
    }
  }

  Future<void> disconnectRealtime() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await _mqttService.disconnect();
    await _log(LogLevel.info, 'mqtt', '应用长连接已断开');
    _setState(state.copyWith(
      deviceOnline: false,
      logs: await _repository.loadLogs(),
    ));
  }

  Future<String?> sendControl(ThingProperty property, Object? rawValue) async {
    if (!state.deviceOnline) {
      return '设备离线，已拦截控制指令';
    }
    final validation = _validator.validateForControl(property, rawValue);
    if (!validation.isValid) return validation.message;
    try {
      if (state.config.usesDeviceToken) {
        await _mqttService.publishProperty(
          config: state.config,
          identifier: property.identifier,
          value: validation.value,
        );
      } else {
        await _apiClient.setDeviceProperty(
          config: state.config,
          identifier: property.identifier,
          value: validation.value,
        );
      }
      final runtimeValue = RuntimeValue(
        identifier: property.identifier,
        value: validation.value,
        time: DateTime.now(),
      );
      await _repository.cacheRuntimeValue(
        runtimeValue,
        retentionDays: _runtimeRetentionDays,
      );
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
    if (!state.config.isReady || !state.config.supportsOpenApi) {
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
        await _repository.cacheRuntimeValue(
          value,
          retentionDays: _runtimeRetentionDays,
        );
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

  Future<void> importBackup(Uint8List bytes) async {
    _setState(state.copyWith(busy: true, statusText: '正在导入备份'));
    try {
      await _repository.importBackup(bytes);
      await _log(LogLevel.info, 'backup', '配置备份已导入');
      await _reloadCoreState(statusText: '备份导入完成');
    } catch (error) {
      await _log(LogLevel.error, 'backup', '配置备份导入失败',
          detail: error.toString());
      _setState(state.copyWith(
        busy: false,
        logs: await _repository.loadLogs(),
        statusText: '备份导入失败',
      ));
      rethrow;
    }
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

  bool _looksLikeJson(ConnectionImportFile file) {
    if (file.name.toLowerCase().endsWith('.json')) return true;
    try {
      final decoded = jsonDecode(utf8.decode(file.bytes, allowMalformed: true));
      return decoded is Map && decoded['properties'] is List;
    } on FormatException {
      return false;
    }
  }

  ProjectConfig _configFromTokenInfo(TokenLogInfo info) {
    if (info.deviceKey.trim().isEmpty) {
      final expiresAt = info.expiresAt;
      if (info.token.trim().isEmpty) {
        throw const FormatException('Token.log 中缺少 key 或 Token');
      }
      if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
        throw const FormatException('Token.log 中的 Token 已过期且没有 key，无法自动续期');
      }
    }
    return state.config.copyWith(
      authMode: AuthMode.deviceToken,
      productId: info.productId,
      deviceName: info.deviceName,
      deviceKey: info.deviceKey,
      deviceToken: info.token,
      deviceTokenMethod: info.method,
      deviceTokenVersion: info.version,
      deviceTokenExpiresAt: info.expiresAt,
      clearDeviceTokenExpiresAt: info.expiresAt == null,
      refreshSeconds: state.config.refreshSeconds,
      historyDays: state.config.historyDays,
    );
  }

  void _ensureProductIdsMatch(String left, String right) {
    final expected = left.trim();
    final actual = right.trim();
    if (expected.isEmpty || actual.isEmpty) return;
    if (expected != actual) {
      throw FormatException(
        'Token.log 的 Product ID ($expected) 与物模型 JSON 的 Product ID ($actual) 不一致',
      );
    }
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

  int get _runtimeRetentionDays {
    final days = state.config.historyDays;
    if (days < 30) return 30;
    if (days > 3650) return 3650;
    return days;
  }

  void _handleRealtimeMessage(OnenetRealtimeMessage message) {
    unawaited(_processRealtimeMessage(message));
  }

  Future<void> _processRealtimeMessage(OnenetRealtimeMessage message) async {
    try {
      await _waitUntilInitialized();
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
        await _repository.cacheRuntimeValue(
          entry.value,
          retentionDays: _runtimeRetentionDays,
        );
      }
      await _log(LogLevel.info, 'mqtt', '收到 ${runtimeValues.length} 个实时属性');
      _setState(
          state.copyWith(values: values, logs: await _repository.loadLogs()));
    } catch (error) {
      try {
        await _log(LogLevel.error, 'mqtt', '实时消息处理失败',
            detail: error.toString());
        await _reloadLogs();
      } catch (_) {
        // Avoid surfacing unhandled errors from fire-and-forget MQTT handling.
      }
    }
  }

  Future<void> _waitUntilInitialized() async {
    if (_initialized) return;
    if (_initFuture == null) {
      await init();
      return;
    }
    await _initFuture;
  }

  void _startPollingFallback() {
    _pollTimer?.cancel();
    if (!state.config.supportsOpenApi) {
      _pollTimer = null;
      return;
    }
    _pollTimer = Timer.periodic(
      Duration(seconds: state.config.refreshSeconds.clamp(5, 3600).toInt()),
      (_) {
        if (state.connectionState != OnenetMqttConnectionState.connected) {
          unawaited(refreshLatest());
        }
      },
    );
  }

  @visibleForTesting
  bool get pollingFallbackActive => _pollTimer?.isActive ?? false;

  void _setState(LinkBoxState next) {
    state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(_messageSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_mqttService.dispose());
    super.dispose();
  }
}
