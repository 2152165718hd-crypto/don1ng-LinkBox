import 'dart:convert';

enum AuthMode { projectGroup, user }

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

enum LogLevel { info, warning, error }

class ProjectConfig {
  const ProjectConfig({
    required this.projectId,
    required this.groupId,
    required this.accessKey,
    required this.productId,
    required this.deviceName,
    this.userId = '',
    this.authMode = AuthMode.projectGroup,
    this.refreshSeconds = 15,
    this.historyDays = 7,
  });

  final String projectId;
  final String groupId;
  final String userId;
  final String accessKey;
  final String productId;
  final String deviceName;
  final AuthMode authMode;
  final int refreshSeconds;
  final int historyDays;

  String get resource {
    if (authMode == AuthMode.user) {
      return 'userid/$userId';
    }
    return 'projectid/$projectId/groupid/$groupId';
  }

  bool get isReady {
    final hasAuthScope =
        authMode == AuthMode.user ? userId.trim().isNotEmpty : groupId.trim().isNotEmpty;
    return projectId.trim().isNotEmpty &&
        hasAuthScope &&
        accessKey.trim().isNotEmpty &&
        productId.trim().isNotEmpty &&
        deviceName.trim().isNotEmpty;
  }

  ProjectConfig copyWith({
    String? projectId,
    String? groupId,
    String? userId,
    String? accessKey,
    String? productId,
    String? deviceName,
    AuthMode? authMode,
    int? refreshSeconds,
    int? historyDays,
  }) {
    return ProjectConfig(
      projectId: projectId ?? this.projectId,
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      accessKey: accessKey ?? this.accessKey,
      productId: productId ?? this.productId,
      deviceName: deviceName ?? this.deviceName,
      authMode: authMode ?? this.authMode,
      refreshSeconds: refreshSeconds ?? this.refreshSeconds,
      historyDays: historyDays ?? this.historyDays,
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
      'auth_mode': authMode.name,
      'refresh_seconds': refreshSeconds,
      'history_days': historyDays,
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
      'auth_mode': authMode.name,
      'refresh_seconds': refreshSeconds,
      'history_days': historyDays,
      if (includeSecret) 'access_key': accessKey,
    };
  }

  factory ProjectConfig.fromMap(Map<String, Object?> map, {String accessKey = ''}) {
    return ProjectConfig(
      projectId: map['project_id'] as String? ?? '',
      groupId: map['group_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      accessKey: accessKey,
      productId: map['product_id'] as String? ?? '',
      deviceName: map['device_name'] as String? ?? '',
      authMode: AuthMode.values.firstWhere(
        (mode) => mode.name == (map['auth_mode'] as String? ?? ''),
        orElse: () => AuthMode.projectGroup,
      ),
      refreshSeconds: (map['refresh_seconds'] as int?) ?? 15,
      historyDays: (map['history_days'] as int?) ?? 7,
    );
  }

  static ProjectConfig empty() {
    return const ProjectConfig(
      projectId: '',
      groupId: '',
      accessKey: '',
      productId: '',
      deviceName: '',
    );
  }
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

  bool get readable => accessMode == AccessMode.readOnly || accessMode == AccessMode.readWrite;
  bool get writable => accessMode == AccessMode.writeOnly || accessMode == AccessMode.readWrite;

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
          ? decoded.map((key, value) => MapEntry(key.toString(), value.toString()))
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
    };
  }

  factory DashboardWidgetConfig.fromMap(Map<String, Object?> map) {
    return DashboardWidgetConfig(
      id: map['id'] as String? ?? '',
      pageId: map['page_id'] as String? ?? '',
      type: DashboardWidgetType.values.firstWhere(
        (type) => type.name == (map['type'] as String? ?? ''),
        orElse: () => DashboardWidgetType.valueCard,
      ),
      propertyIdentifier: map['property_identifier'] as String? ?? '',
      title: map['title'] as String? ?? '',
      x: (map['x'] as num? ?? 0).toDouble(),
      y: (map['y'] as num? ?? 0).toDouble(),
      width: (map['width'] as num? ?? 180).toDouble(),
      height: (map['height'] as num? ?? 110).toDouble(),
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
      level: LogLevel.values.firstWhere(
        (level) => level.name == (map['level'] as String? ?? ''),
        orElse: () => LogLevel.info,
      ),
      type: map['type'] as String? ?? '',
      message: map['message'] as String? ?? '',
      detail: map['detail'] as String? ?? '',
    );
  }
}
