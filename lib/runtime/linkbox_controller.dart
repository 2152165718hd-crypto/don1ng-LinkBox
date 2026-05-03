import 'dart:async';
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

class ConnectionFailureInfo {
  const ConnectionFailureInfo({
    required this.field,
    required this.reason,
    required this.suggestion,
    this.detail = '',
  });

  final String field;
  final String reason;
  final String suggestion;
  final String detail;
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

  Future<ProjectConfig> importTokenLog(ConnectionImportFile file) async {
    _setState(state.copyWith(busy: true, statusText: '正在导入 Token.log'));
    try {
      final tokenInfo = await TokenLogParser().parseBytes(file.bytes);
      final config = _configFromTokenInfo(tokenInfo);
      await _repository.saveConfig(config);
      await _log(
        LogLevel.info,
        'token-log',
        '已导入 Token.log：${config.productId}/${config.deviceName}',
      );
      await _reloadCoreState(statusText: 'Token.log 导入完成，可直接点击连接');
      return config;
    } catch (error) {
      await _log(LogLevel.error, 'token-log', 'Token.log 导入失败',
          detail: error.toString());
      _setState(state.copyWith(
        busy: false,
        logs: await _repository.loadLogs(),
        statusText: 'Token.log 导入失败',
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
      await _reloadCoreState(statusText: '物模型导入完成，已生成可编辑实时 UI 卡片');
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
    await _log(LogLevel.info, 'dashboard', '已补齐默认实时 UI 卡片');
    await _reloadCoreState(statusText: '默认实时 UI 已补齐');
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

  Future<ConnectionFailureInfo?> connectRealtime() async {
    final config = state.config;
    final configIssue = _connectionConfigIssue(config);
    if (configIssue != null) {
      await _log(LogLevel.warning, 'mqtt', configIssue.reason,
          detail: configIssue.detail);
      await _reloadLogs();
      return configIssue;
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
      return null;
    } catch (error) {
      if (config.supportsOpenApi) {
        _startPollingFallback();
      }
      final failure = _connectionFailureForError(error, config);
      await _log(LogLevel.error, 'mqtt', failure.reason,
          detail: error.toString());
      _setState(state.copyWith(
        busy: false,
        connectionState: OnenetMqttConnectionState.failed,
        logs: await _repository.loadLogs(),
        statusText: '连接失败',
      ));
      return failure;
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
        '当前 Product ID ($expected) 与物模型 JSON 的 Product ID ($actual) 不一致',
      );
    }
  }

  ConnectionFailureInfo? _connectionConfigIssue(ProjectConfig config) {
    final missing = <String>[];
    if (config.productId.trim().isEmpty) missing.add('Product ID');
    if (config.deviceName.trim().isEmpty) missing.add('Device Name');

    if (config.authMode == AuthMode.deviceToken) {
      final expiresAt = config.deviceTokenExpiresAt;
      final hasKey = config.deviceKey.trim().isNotEmpty;
      final hasToken = config.deviceToken.trim().isNotEmpty;
      if (!hasKey && !hasToken) {
        missing.add('Device Key 或 Token');
      } else if (!hasKey &&
          hasToken &&
          expiresAt != null &&
          !expiresAt.isAfter(DateTime.now())) {
        return const ConnectionFailureInfo(
          field: 'Token',
          reason: 'Token 已过期，不能继续用于设备 MQTT 登录。',
          suggestion:
              '重新从 OneNET Studio 导出 Token.log，或在手动填写里改填 Device Key 让应用自动生成新 Token。',
        );
      }
    } else {
      if (config.projectId.trim().isEmpty) missing.add('Project ID');
      if (config.authMode == AuthMode.user) {
        if (config.userId.trim().isEmpty) missing.add('User ID');
      } else if (config.groupId.trim().isEmpty) {
        missing.add('Group ID');
      }
      if (config.accessKey.trim().isEmpty) missing.add('Access Key');
    }

    if (missing.isEmpty) return null;
    return ConnectionFailureInfo(
      field: missing.join('、'),
      reason: '连接信息不完整：${missing.join('、')} 不能为空。',
      suggestion: config.authMode == AuthMode.deviceToken
          ? '在设备页导入 Token.log，或手动填写 Product ID、Device Name，并至少填写 Device Key 或 Token。'
          : '在高级应用接入中补齐应用鉴权字段，再重新连接。',
    );
  }

  ConnectionFailureInfo _connectionFailureForError(
    Object error,
    ProjectConfig config,
  ) {
    final detail = error.toString();
    if (error is FormatException) {
      final message = error.message;
      final field = message.contains('AccessKey')
          ? 'Access Key'
          : message.contains('DeviceKey') || message.contains('key')
              ? 'Device Key'
              : message.contains('Token')
                  ? 'Token'
                  : '鉴权信息';
      return ConnectionFailureInfo(
        field: field,
        reason: message,
        suggestion: field == 'Access Key'
            ? '复制 OneNET Studio 里的完整 AccessKey，确认没有空格或换行。'
            : '重新复制 OneNET Studio 里的 Device Key 或 Token；如果使用 Token，确认没有过期。',
        detail: detail,
      );
    }
    final mqttEndpoint = config.mqttUseTls
        ? 'studio-mqtts.heclouds.com:8883'
        : 'studio-mqtt.heclouds.com:1883';
    if (error is SocketException) {
      return ConnectionFailureInfo(
        field: '网络连接',
        reason: '无法连接 OneNET MQTT 服务器。',
        suggestion: '检查当前网络、DNS、代理或防火墙是否允许访问 $mqttEndpoint，然后重新连接。',
        detail: detail,
      );
    }
    if (error is HandshakeException && config.mqttUseTls) {
      return ConnectionFailureInfo(
        field: 'TLS 连接',
        reason: 'MQTT TLS 握手失败。',
        suggestion: '检查设备时间、系统证书和网络代理；确认 8883 端口没有被拦截。',
        detail: detail,
      );
    }
    if (detail.contains('badUsernameOrPassword') ||
        detail.contains('notAuthorized') ||
        detail.contains('MQTT 连接失败')) {
      return ConnectionFailureInfo(
        field: config.usesDeviceToken
            ? 'Product ID / Device Name / Token'
            : '应用鉴权',
        reason: 'OneNET 拒绝 MQTT 登录。',
        suggestion: config.usesDeviceToken
            ? '确认 Product ID、Device Name 与 OneNET 设备一致；重新导入 Token.log，或改填 Device Key 自动生成 Token。'
            : '确认 Project ID、Group ID/User ID、AccessKey 和设备信息都来自同一 OneNET 项目。',
        detail: detail,
      );
    }
    return ConnectionFailureInfo(
      field: '连接',
      reason: 'MQTT 连接失败。',
      suggestion: '检查 OneNET 设备是否启用 MQTT、当前网络是否可访问 OneNET，并重新核对所有连接字段。',
      detail: detail,
    );
  }

  Future<void> _ensureDashboard(List<ThingProperty> properties) async {
    final pages = await _repository.loadPages();
    final widgets = await _repository.loadWidgets();
    final dashboard = _dashboardFactory.mergeForProperties(
      properties: properties,
      pages: pages,
      widgets: widgets,
    );
    await _repository.replaceDashboard(
      pages: dashboard.pages,
      widgets: dashboard.widgets,
    );
  }

  Future<void> _removeLegacyTrendWidgets() async {
    final pages = await _repository.loadPages();
    final widgets = await _repository.loadWidgets();
    final filtered = widgets
        .where((item) => item.displayMode != DashboardDisplayMode.trendChart)
        .toList();
    if (filtered.length == widgets.length) return;
    await _repository.replaceDashboard(pages: pages, widgets: filtered);
  }

  Future<void> _reloadCoreState({String statusText = ''}) async {
    await _removeLegacyTrendWidgets();
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
