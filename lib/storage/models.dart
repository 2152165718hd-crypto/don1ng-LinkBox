import 'dart:convert';

enum AuthMode { deviceToken, projectGroup, user }

enum AccessMode { readOnly, writeOnly, readWrite }

enum ThingDataType {
  int32,
  int64,
  float,
  doubleType,
  boolType,
  enumType,
  stringType,
  struct,
  bitmap,
  unknown,
}

enum DashboardWidgetType {
  valueCard,
  switchControl,
  slider,
  enumSelect,
  trendChart,
  textLabel,
}

enum DashboardDisplayMode {
  value,
  progress,
  slider,
  gauge,
  switcher,
  button,
  enumSelect,
  status,
  text,
  trendChart,
}

enum DashboardIconKind {
  none,
  material,
  builtinSvg,
  builtinPng,
  uploadedPng,
}

enum LogLevel { info, warning, error }

class ProjectConfig {
  const ProjectConfig({
    required this.projectId,
    required this.groupId,
    required this.accessKey,
    required this.productId,
    required this.deviceName,
    this.deviceKey = '',
    this.deviceToken = '',
    this.deviceTokenMethod = 'md5',
    this.deviceTokenVersion = '2018-10-31',
    this.deviceTokenExpiresAt,
    this.userId = '',
    this.authMode = AuthMode.deviceToken,
    this.refreshSeconds = 15,
    this.historyDays = 7,
    this.mqttUseTls = false,
  });

  final String projectId;
  final String groupId;
  final String userId;
  final String accessKey;
  final String productId;
  final String deviceName;
  final String deviceKey;
  final String deviceToken;
  final String deviceTokenMethod;
  final String deviceTokenVersion;
  final DateTime? deviceTokenExpiresAt;
  final AuthMode authMode;
  final int refreshSeconds;
  final int historyDays;
  final bool mqttUseTls;

  String get resource {
    if (authMode == AuthMode.deviceToken) {
      return deviceResource;
    }
    if (authMode == AuthMode.user) {
      return 'userid/$userId';
    }
    return 'projectid/$projectId/groupid/$groupId';
  }

  String get deviceResource => 'products/$productId/devices/$deviceName';

  bool get usesDeviceToken => authMode == AuthMode.deviceToken;

  bool get supportsOpenApi => authMode != AuthMode.deviceToken;

  bool get _hasUsableImportedDeviceToken {
    if (deviceToken.trim().isEmpty) return false;
    final expiresAt = deviceTokenExpiresAt;
    if (expiresAt == null) return true;
    return expiresAt.isAfter(DateTime.now());
  }

  bool get isReady {
    final hasDeviceIdentity =
        productId.trim().isNotEmpty && deviceName.trim().isNotEmpty;
    if (authMode == AuthMode.deviceToken) {
      return hasDeviceIdentity &&
          (deviceKey.trim().isNotEmpty || _hasUsableImportedDeviceToken);
    }
    final hasAuthScope = authMode == AuthMode.user
        ? userId.trim().isNotEmpty
        : groupId.trim().isNotEmpty;
    return hasDeviceIdentity &&
        projectId.trim().isNotEmpty &&
        hasAuthScope &&
        accessKey.trim().isNotEmpty;
  }

  ProjectConfig copyWith({
    String? projectId,
    String? groupId,
    String? userId,
    String? accessKey,
    String? productId,
    String? deviceName,
    String? deviceKey,
    String? deviceToken,
    String? deviceTokenMethod,
    String? deviceTokenVersion,
    DateTime? deviceTokenExpiresAt,
    bool clearDeviceTokenExpiresAt = false,
    AuthMode? authMode,
    int? refreshSeconds,
    int? historyDays,
    bool? mqttUseTls,
  }) {
    return ProjectConfig(
      projectId: projectId ?? this.projectId,
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      accessKey: accessKey ?? this.accessKey,
      productId: productId ?? this.productId,
      deviceName: deviceName ?? this.deviceName,
      deviceKey: deviceKey ?? this.deviceKey,
      deviceToken: deviceToken ?? this.deviceToken,
      deviceTokenMethod: deviceTokenMethod ?? this.deviceTokenMethod,
      deviceTokenVersion: deviceTokenVersion ?? this.deviceTokenVersion,
      deviceTokenExpiresAt: clearDeviceTokenExpiresAt
          ? null
          : deviceTokenExpiresAt ?? this.deviceTokenExpiresAt,
      authMode: authMode ?? this.authMode,
      refreshSeconds: refreshSeconds ?? this.refreshSeconds,
      historyDays: historyDays ?? this.historyDays,
      mqttUseTls: mqttUseTls ?? this.mqttUseTls,
    );
  }

  Map<String, Object?> toDbMap({required bool includeSecret}) {
    return {
      'id': 1,
      'project_id': projectId,
      'group_id': groupId,
      'user_id': userId,
      'product_id': productId,
      'device_name': deviceName,
      'device_token_method': deviceTokenMethod,
      'device_token_version': deviceTokenVersion,
      'device_token_expires_at': deviceTokenExpiresAt?.millisecondsSinceEpoch,
      'auth_mode': authMode.name,
      'refresh_seconds': refreshSeconds,
      'history_days': historyDays,
      'mqtt_use_tls': mqttUseTls ? 1 : 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      if (includeSecret) 'access_key': accessKey,
    };
  }

  Map<String, Object?> toExportMap({bool includeSecret = false}) {
    return {
      'project_id': projectId,
      'group_id': groupId,
      'user_id': userId,
      'product_id': productId,
      'device_name': deviceName,
      'device_token_method': deviceTokenMethod,
      'device_token_version': deviceTokenVersion,
      'device_token_expires_at': deviceTokenExpiresAt?.millisecondsSinceEpoch,
      'auth_mode': authMode.name,
      'refresh_seconds': refreshSeconds,
      'history_days': historyDays,
      'mqtt_use_tls': mqttUseTls,
      if (includeSecret) ...{
        'access_key': accessKey,
        'device_key': deviceKey,
        'device_token': deviceToken,
      },
    };
  }

  factory ProjectConfig.fromMap(Map<String, Object?> map,
      {String accessKey = '', String deviceKey = '', String deviceToken = ''}) {
    final expiresMillis = map['device_token_expires_at'];
    return ProjectConfig(
      projectId: map['project_id'] as String? ?? '',
      groupId: map['group_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      accessKey: accessKey,
      productId: map['product_id'] as String? ?? '',
      deviceName: map['device_name'] as String? ?? '',
      deviceKey: deviceKey,
      deviceToken: deviceToken,
      deviceTokenMethod: map['device_token_method'] as String? ?? 'md5',
      deviceTokenVersion:
          map['device_token_version'] as String? ?? '2018-10-31',
      deviceTokenExpiresAt: expiresMillis is num
          ? DateTime.fromMillisecondsSinceEpoch(expiresMillis.toInt())
          : null,
      authMode: AuthMode.values.firstWhere(
        (mode) => mode.name == (map['auth_mode'] as String? ?? ''),
        orElse: () => AuthMode.deviceToken,
      ),
      refreshSeconds: (map['refresh_seconds'] as int?) ?? 15,
      historyDays: (map['history_days'] as int?) ?? 7,
      mqttUseTls: _boolFromMap(map['mqtt_use_tls']),
    );
  }

  static ProjectConfig empty() {
    return const ProjectConfig(
      projectId: '',
      groupId: '',
      accessKey: '',
      productId: '',
      deviceName: '',
      authMode: AuthMode.deviceToken,
    );
  }
}

bool _boolFromMap(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  return false;
}

class ThingProperty {
  const ThingProperty({
    required this.identifier,
    required this.name,
    required this.type,
    required this.accessMode,
    this.description = '',
    this.unit = '',
    this.min,
    this.max,
    this.step,
    this.enumValues = const {},
    this.rawType = '',
    this.required = false,
  });

  final String identifier;
  final String name;
  final String description;
  final ThingDataType type;
  final AccessMode accessMode;
  final String unit;
  final num? min;
  final num? max;
  final num? step;
  final Map<String, String> enumValues;
  final String rawType;
  final bool required;

  bool get readable =>
      accessMode == AccessMode.readOnly || accessMode == AccessMode.readWrite;
  bool get writable =>
      accessMode == AccessMode.writeOnly || accessMode == AccessMode.readWrite;

  bool get isNumeric {
    return type == ThingDataType.int32 ||
        type == ThingDataType.int64 ||
        type == ThingDataType.float ||
        type == ThingDataType.doubleType;
  }

  bool get isControllable {
    return writable &&
        (type == ThingDataType.boolType ||
            type == ThingDataType.enumType ||
            type == ThingDataType.int32 ||
            type == ThingDataType.int64 ||
            type == ThingDataType.float ||
            type == ThingDataType.doubleType ||
            type == ThingDataType.stringType);
  }

  String get displayName => name.trim().isEmpty ? identifier : name;

  Map<String, Object?> toDbMap() {
    return {
      'identifier': identifier,
      'name': name,
      'description': description,
      'type': type.name,
      'access_mode': accessMode.name,
      'unit': unit,
      'min_value': min,
      'max_value': max,
      'step_value': step,
      'enum_values': jsonEncode(enumValues),
      'raw_type': rawType,
      'is_required': required ? 1 : 0,
    };
  }

  Map<String, Object?> toExportMap() => toDbMap();

  factory ThingProperty.fromMap(Map<String, Object?> map) {
    final rawEnum = map['enum_values'] as String? ?? '{}';
    final decoded = jsonDecode(rawEnum);
    return ThingProperty(
      identifier: map['identifier'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      type: ThingDataType.values.firstWhere(
        (type) => type.name == (map['type'] as String? ?? ''),
        orElse: () => ThingDataType.unknown,
      ),
      accessMode: AccessMode.values.firstWhere(
        (mode) => mode.name == (map['access_mode'] as String? ?? ''),
        orElse: () => AccessMode.readOnly,
      ),
      unit: map['unit'] as String? ?? '',
      min: map['min_value'] as num?,
      max: map['max_value'] as num?,
      step: map['step_value'] as num?,
      enumValues: decoded is Map
          ? decoded
              .map((key, value) => MapEntry(key.toString(), value.toString()))
          : const {},
      rawType: map['raw_type'] as String? ?? '',
      required: (map['is_required'] as int? ?? 0) == 1,
    );
  }
}

class DashboardPageConfig {
  const DashboardPageConfig({
    required this.id,
    required this.name,
    this.orderIndex = 0,
  });

  final String id;
  final String name;
  final int orderIndex;

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'name': name,
      'order_index': orderIndex,
    };
  }

  factory DashboardPageConfig.fromMap(Map<String, Object?> map) {
    return DashboardPageConfig(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      orderIndex: map['order_index'] as int? ?? 0,
    );
  }
}

class DashboardWidgetConfig {
  const DashboardWidgetConfig({
    required this.id,
    required this.pageId,
    required this.type,
    required this.propertyIdentifier,
    required this.title,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.displayMode,
    this.iconKind = DashboardIconKind.material,
    this.iconValue = '',
    this.showUnit = true,
    this.decimalDigits = 1,
    this.backgroundColor = 0xFFFFFFFF,
    this.textColor = 0xFF101828,
  });

  final String id;
  final String pageId;
  final DashboardWidgetType type;
  final String propertyIdentifier;
  final String title;
  final double x;
  final double y;
  final double width;
  final double height;
  final DashboardDisplayMode displayMode;
  final DashboardIconKind iconKind;
  final String iconValue;
  final bool showUnit;
  final int decimalDigits;
  final int backgroundColor;
  final int textColor;

  bool get isTrend => displayMode == DashboardDisplayMode.trendChart;

  DashboardWidgetConfig copyWith({
    String? id,
    String? pageId,
    DashboardWidgetType? type,
    String? propertyIdentifier,
    String? title,
    double? x,
    double? y,
    double? width,
    double? height,
    DashboardDisplayMode? displayMode,
    DashboardIconKind? iconKind,
    String? iconValue,
    bool? showUnit,
    int? decimalDigits,
    int? backgroundColor,
    int? textColor,
  }) {
    return DashboardWidgetConfig(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      type: type ?? this.type,
      propertyIdentifier: propertyIdentifier ?? this.propertyIdentifier,
      title: title ?? this.title,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      displayMode: displayMode ?? this.displayMode,
      iconKind: iconKind ?? this.iconKind,
      iconValue: iconValue ?? this.iconValue,
      showUnit: showUnit ?? this.showUnit,
      decimalDigits: decimalDigits ?? this.decimalDigits,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'page_id': pageId,
      'type': type.name,
      'property_identifier': propertyIdentifier,
      'title': title,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'display_mode': displayMode.name,
      'icon_kind': iconKind.name,
      'icon_value': iconValue,
      'show_unit': showUnit ? 1 : 0,
      'decimal_digits': decimalDigits,
      'background_color': backgroundColor,
      'text_color': textColor,
    };
  }

  Map<String, Object?> toExportMap() => toDbMap();

  factory DashboardWidgetConfig.fromMap(Map<String, Object?> map) {
    final type = _enumFromName(
      DashboardWidgetType.values,
      map['type'] as String?,
      DashboardWidgetType.valueCard,
    );
    final displayMode = _enumFromName(
      DashboardDisplayMode.values,
      map['display_mode'] as String?,
      _legacyDisplayMode(type),
    );
    return DashboardWidgetConfig(
      id: map['id'] as String? ?? '',
      pageId: map['page_id'] as String? ?? '',
      type: type,
      propertyIdentifier: map['property_identifier'] as String? ?? '',
      title: map['title'] as String? ?? '',
      x: (map['x'] as num? ?? 0).toDouble(),
      y: (map['y'] as num? ?? 0).toDouble(),
      width: (map['width'] as num? ?? 180).toDouble(),
      height: (map['height'] as num? ?? 110).toDouble(),
      displayMode: displayMode,
      iconKind: _enumFromName(
        DashboardIconKind.values,
        map['icon_kind'] as String?,
        DashboardIconKind.material,
      ),
      iconValue: map['icon_value'] as String? ?? '',
      showUnit: (map['show_unit'] as int? ?? 1) == 1,
      decimalDigits: (map['decimal_digits'] as int? ?? 1).clamp(0, 6).toInt(),
      backgroundColor: (map['background_color'] as int?) ?? 0xFFFFFFFF,
      textColor: (map['text_color'] as int?) ?? 0xFF101828,
    );
  }
}

class RuntimeValue {
  const RuntimeValue({
    required this.identifier,
    required this.value,
    required this.time,
  });

  final String identifier;
  final Object? value;
  final DateTime time;

  Map<String, Object?> toDbMap() {
    return {
      'identifier': identifier,
      'value_json': jsonEncode(value),
      'time': time.millisecondsSinceEpoch,
    };
  }

  factory RuntimeValue.fromMap(Map<String, Object?> map) {
    final raw = map['value_json'] as String? ?? 'null';
    return RuntimeValue(
      identifier: map['identifier'] as String? ?? '',
      value: jsonDecode(raw),
      time: DateTime.fromMillisecondsSinceEpoch(map['time'] as int? ?? 0),
    );
  }
}

class AppLogEntry {
  const AppLogEntry({
    required this.time,
    required this.level,
    required this.type,
    required this.message,
    this.detail = '',
  });

  final DateTime time;
  final LogLevel level;
  final String type;
  final String message;
  final String detail;

  Map<String, Object?> toDbMap() {
    return {
      'time': time.millisecondsSinceEpoch,
      'level': level.name,
      'type': type,
      'message': message,
      'detail': detail,
    };
  }

  factory AppLogEntry.fromMap(Map<String, Object?> map) {
    return AppLogEntry(
      time: DateTime.fromMillisecondsSinceEpoch(map['time'] as int? ?? 0),
      level: _enumFromName(
          LogLevel.values, map['level'] as String?, LogLevel.info),
      type: map['type'] as String? ?? '',
      message: map['message'] as String? ?? '',
      detail: map['detail'] as String? ?? '',
    );
  }
}

List<DashboardDisplayMode> compatibleDisplayModes(ThingProperty property) {
  if (property.isNumeric) {
    final modes = <DashboardDisplayMode>[
      DashboardDisplayMode.value,
      DashboardDisplayMode.progress,
      DashboardDisplayMode.gauge,
      DashboardDisplayMode.trendChart,
      DashboardDisplayMode.status,
    ];
    if (property.writable) {
      modes.insert(2, DashboardDisplayMode.slider);
    }
    return modes;
  }
  if (property.type == ThingDataType.boolType) {
    final modes = <DashboardDisplayMode>[
      DashboardDisplayMode.status,
      DashboardDisplayMode.value,
    ];
    if (property.writable) {
      modes.insertAll(0, const [
        DashboardDisplayMode.switcher,
        DashboardDisplayMode.button,
      ]);
    }
    return modes;
  }
  if (property.type == ThingDataType.enumType) {
    final modes = <DashboardDisplayMode>[
      DashboardDisplayMode.status,
      DashboardDisplayMode.value,
    ];
    if (property.writable) {
      modes.insert(0, DashboardDisplayMode.enumSelect);
    }
    return modes;
  }
  return const [
    DashboardDisplayMode.text,
    DashboardDisplayMode.status,
    DashboardDisplayMode.value,
  ];
}

DashboardDisplayMode defaultDisplayModeFor(ThingProperty property) {
  if (property.type == ThingDataType.boolType && property.writable) {
    return DashboardDisplayMode.switcher;
  }
  if (property.type == ThingDataType.enumType && property.writable) {
    return DashboardDisplayMode.enumSelect;
  }
  if (property.isNumeric && property.writable) {
    return DashboardDisplayMode.slider;
  }
  if (property.type == ThingDataType.stringType) {
    return DashboardDisplayMode.text;
  }
  return DashboardDisplayMode.value;
}

DashboardWidgetType widgetTypeForDisplayMode(DashboardDisplayMode mode) {
  switch (mode) {
    case DashboardDisplayMode.slider:
      return DashboardWidgetType.slider;
    case DashboardDisplayMode.switcher:
    case DashboardDisplayMode.button:
      return DashboardWidgetType.switchControl;
    case DashboardDisplayMode.enumSelect:
      return DashboardWidgetType.enumSelect;
    case DashboardDisplayMode.trendChart:
      return DashboardWidgetType.trendChart;
    case DashboardDisplayMode.text:
      return DashboardWidgetType.textLabel;
    case DashboardDisplayMode.value:
    case DashboardDisplayMode.progress:
    case DashboardDisplayMode.gauge:
    case DashboardDisplayMode.status:
      return DashboardWidgetType.valueCard;
  }
}

DashboardDisplayMode _legacyDisplayMode(DashboardWidgetType type) {
  switch (type) {
    case DashboardWidgetType.switchControl:
      return DashboardDisplayMode.switcher;
    case DashboardWidgetType.slider:
      return DashboardDisplayMode.slider;
    case DashboardWidgetType.enumSelect:
      return DashboardDisplayMode.enumSelect;
    case DashboardWidgetType.trendChart:
      return DashboardDisplayMode.trendChart;
    case DashboardWidgetType.textLabel:
      return DashboardDisplayMode.text;
    case DashboardWidgetType.valueCard:
      return DashboardDisplayMode.value;
  }
}

T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
