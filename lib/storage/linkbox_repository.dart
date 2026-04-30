import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class LinkBoxRepository {
  LinkBoxRepository({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _accessKeyStorageKey = 'onenet_access_key';
  static const _maxLogEntries = 1000;
  final FlutterSecureStorage _secureStorage;
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'don1ng_linkbox.db');
    _db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    return _db!;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE project_config (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        project_id TEXT NOT NULL,
        group_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        device_name TEXT NOT NULL,
        auth_mode TEXT NOT NULL,
        refresh_seconds INTEGER NOT NULL,
        history_days INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE thing_properties (
        identifier TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        type TEXT NOT NULL,
        access_mode TEXT NOT NULL,
        unit TEXT NOT NULL,
        min_value REAL,
        max_value REAL,
        step_value REAL,
        enum_values TEXT NOT NULL,
        raw_type TEXT NOT NULL,
        is_required INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE dashboard_pages (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        order_index INTEGER NOT NULL
      )
    ''');
    await db.execute(_dashboardWidgetsSchema);
    await db.execute('''
      CREATE TABLE runtime_values (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        identifier TEXT NOT NULL,
        value_json TEXT NOT NULL,
        time INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_runtime_values_identifier_time ON runtime_values(identifier, time)');
    await db.execute('''
      CREATE TABLE app_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        time INTEGER NOT NULL,
        level TEXT NOT NULL,
        type TEXT NOT NULL,
        message TEXT NOT NULL,
        detail TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeSchema(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(db, 'dashboard_widgets', 'display_mode',
          "TEXT NOT NULL DEFAULT 'value'");
      await _addColumnIfMissing(db, 'dashboard_widgets', 'icon_kind',
          "TEXT NOT NULL DEFAULT 'material'");
      await _addColumnIfMissing(
          db, 'dashboard_widgets', 'icon_value', "TEXT NOT NULL DEFAULT ''");
      await _addColumnIfMissing(
          db, 'dashboard_widgets', 'show_unit', 'INTEGER NOT NULL DEFAULT 1');
      await _addColumnIfMissing(db, 'dashboard_widgets', 'decimal_digits',
          'INTEGER NOT NULL DEFAULT 1');
      await _addColumnIfMissing(
        db,
        'dashboard_widgets',
        'background_color',
        'INTEGER NOT NULL DEFAULT 4294967295',
      );
      await _addColumnIfMissing(
        db,
        'dashboard_widgets',
        'text_color',
        'INTEGER NOT NULL DEFAULT 4279242760',
      );
      await db.execute('''
        UPDATE dashboard_widgets
        SET display_mode = CASE type
          WHEN 'switchControl' THEN 'switcher'
          WHEN 'slider' THEN 'slider'
          WHEN 'enumSelect' THEN 'enumSelect'
          WHEN 'trendChart' THEN 'trendChart'
          WHEN 'textLabel' THEN 'text'
          ELSE 'value'
        END
      ''');
    }
  }

  static const _dashboardWidgetsSchema = '''
      CREATE TABLE dashboard_widgets (
        id TEXT PRIMARY KEY,
        page_id TEXT NOT NULL,
        type TEXT NOT NULL,
        property_identifier TEXT NOT NULL,
        title TEXT NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        width REAL NOT NULL,
        height REAL NOT NULL,
        display_mode TEXT NOT NULL,
        icon_kind TEXT NOT NULL,
        icon_value TEXT NOT NULL,
        show_unit INTEGER NOT NULL,
        decimal_digits INTEGER NOT NULL,
        background_color INTEGER NOT NULL,
        text_color INTEGER NOT NULL
      )
    ''';

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((item) => item['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<ProjectConfig> loadConfig() async {
    final db = await database;
    final rows = await db.query('project_config', limit: 1);
    final accessKey =
        await _secureStorage.read(key: _accessKeyStorageKey) ?? '';
    if (rows.isEmpty) {
      return ProjectConfig.empty().copyWith(accessKey: accessKey);
    }
    return ProjectConfig.fromMap(rows.first, accessKey: accessKey);
  }

  Future<void> saveConfig(ProjectConfig config) async {
    final db = await database;
    await _secureStorage.write(
        key: _accessKeyStorageKey, value: config.accessKey);
    await db.insert(
      'project_config',
      config.toDbMap(includeSecret: false),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ThingProperty>> loadProperties() async {
    final db = await database;
    final rows = await db.query('thing_properties', orderBy: 'identifier ASC');
    return rows.map(ThingProperty.fromMap).toList();
  }

  Future<void> replaceProperties(List<ThingProperty> properties) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('thing_properties');
      for (final property in properties) {
        await txn.insert('thing_properties', property.toDbMap());
      }
    });
  }

  Future<void> upsertProperties(List<ThingProperty> properties) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final property in properties) {
        await txn.insert(
          'thing_properties',
          property.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> deleteProperty(String identifier) async {
    final db = await database;
    await db.delete('thing_properties',
        where: 'identifier = ?', whereArgs: [identifier]);
    await db.delete('dashboard_widgets',
        where: 'property_identifier = ?', whereArgs: [identifier]);
  }

  Future<void> clearThingModel() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('thing_properties');
      await txn.delete('dashboard_widgets');
      await txn.delete('dashboard_pages');
      await txn.delete('runtime_values');
    });
  }

  Future<List<DashboardPageConfig>> loadPages() async {
    final db = await database;
    final rows = await db.query('dashboard_pages', orderBy: 'order_index ASC');
    return rows.map(DashboardPageConfig.fromMap).toList();
  }

  Future<List<DashboardWidgetConfig>> loadWidgets() async {
    final db = await database;
    final rows = await db.query('dashboard_widgets', orderBy: 'y ASC, x ASC');
    return rows.map(DashboardWidgetConfig.fromMap).toList();
  }

  Future<void> replaceDashboard({
    required List<DashboardPageConfig> pages,
    required List<DashboardWidgetConfig> widgets,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('dashboard_widgets');
      await txn.delete('dashboard_pages');
      for (final page in pages) {
        await txn.insert('dashboard_pages', page.toDbMap());
      }
      for (final widget in widgets) {
        await txn.insert('dashboard_widgets', widget.toDbMap());
      }
    });
  }

  Future<void> savePage(DashboardPageConfig page) async {
    final db = await database;
    await db.insert(
      'dashboard_pages',
      page.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveWidgets(List<DashboardWidgetConfig> widgets) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final widget in widgets) {
        await txn.insert(
          'dashboard_widgets',
          widget.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> saveWidget(DashboardWidgetConfig widget) async {
    final db = await database;
    await db.insert(
      'dashboard_widgets',
      widget.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteWidget(String id) async {
    final db = await database;
    await db.delete('dashboard_widgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> saveUploadedIcon({
    required Uint8List bytes,
    required String originalName,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final iconDir = Directory(p.join(dir.path, 'user_icons'));
    if (!await iconDir.exists()) {
      await iconDir.create(recursive: true);
    }
    final safeName = originalName.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final file = File(p.join(
        iconDir.path, fileName.endsWith('.png') ? fileName : '$fileName.png'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> cacheRuntimeValue(
    RuntimeValue value, {
    int retentionDays = 30,
  }) async {
    final db = await database;
    await db.insert('runtime_values', value.toDbMap());
    await pruneOldValues(retentionDays: retentionDays);
  }

  Future<void> pruneOldValues({int retentionDays = 30}) async {
    if (retentionDays <= 0) return;
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: retentionDays))
        .millisecondsSinceEpoch;
    await db.delete(
      'runtime_values',
      where: 'time < ?',
      whereArgs: [cutoff],
    );
  }

  Future<Map<String, RuntimeValue>> latestValues() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT rv.* FROM runtime_values rv
      INNER JOIN (
        SELECT identifier, MAX(time) AS max_time
        FROM runtime_values
        GROUP BY identifier
      ) latest ON rv.identifier = latest.identifier AND rv.time = latest.max_time
    ''');
    return {
      for (final value in rows.map(RuntimeValue.fromMap))
        value.identifier: value,
    };
  }

  Future<List<RuntimeValue>> history({
    required String identifier,
    required DateTime start,
    required DateTime end,
    int limit = 500,
  }) async {
    final db = await database;
    final rows = await db.query(
      'runtime_values',
      where: 'identifier = ? AND time >= ? AND time <= ?',
      whereArgs: [
        identifier,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch
      ],
      orderBy: 'time ASC',
      limit: limit,
    );
    return rows.map(RuntimeValue.fromMap).toList();
  }

  Future<void> addLog(AppLogEntry entry) async {
    final db = await database;
    await db.insert('app_logs', entry.toDbMap());
    await db.rawDelete('''
      DELETE FROM app_logs
      WHERE id NOT IN (
        SELECT id FROM app_logs
        ORDER BY time DESC, id DESC
        LIMIT $_maxLogEntries
      )
    ''');
  }

  Future<List<AppLogEntry>> loadLogs({int limit = 200}) async {
    final db = await database;
    final rows = await db.query('app_logs', orderBy: 'time DESC', limit: limit);
    return rows.map(AppLogEntry.fromMap).toList();
  }

  Future<File> exportBackup({
    required bool includeSecret,
  }) async {
    final config = await loadConfig();
    final properties = await loadProperties();
    final pages = await loadPages();
    final widgets = await loadWidgets();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(
      dir.path,
      'don1ng-linkbox-backup-${_fileTimestamp(DateTime.now())}.json',
    ));
    final data = {
      'schema': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'project_config': config.toExportMap(includeSecret: includeSecret),
      'thing_properties': properties.map((item) => item.toExportMap()).toList(),
      'dashboard_pages': pages.map((item) => item.toDbMap()).toList(),
      'dashboard_widgets': widgets.map((item) => item.toExportMap()).toList(),
    };
    return file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<void> importBackup(Uint8List bytes) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('备份文件根节点必须是 JSON 对象');
    }
    final root = _stringKeyMap(decoded);
    final configMap = _requiredMap(root['project_config'], 'project_config');
    final existingConfig = await loadConfig();
    final importedAccessKey =
        configMap['access_key']?.toString() ?? existingConfig.accessKey;
    final config = ProjectConfig.fromMap(
      configMap,
      accessKey: importedAccessKey,
    );
    final properties = _mapList(root['thing_properties'], 'thing_properties')
        .map((item) => ThingProperty.fromMap(_normalizePropertyMap(item)))
        .toList();
    final pages = _mapList(root['dashboard_pages'], 'dashboard_pages')
        .map(DashboardPageConfig.fromMap)
        .toList();
    final widgets = _mapList(root['dashboard_widgets'], 'dashboard_widgets')
        .map(DashboardWidgetConfig.fromMap)
        .toList();

    await saveConfig(config);
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('thing_properties');
      await txn.delete('dashboard_widgets');
      await txn.delete('dashboard_pages');
      for (final property in properties) {
        await txn.insert('thing_properties', property.toDbMap());
      }
      for (final page in pages) {
        await txn.insert('dashboard_pages', page.toDbMap());
      }
      for (final widget in widgets) {
        await txn.insert('dashboard_widgets', widget.toDbMap());
      }
    });
  }

  String _fileTimestamp(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}-'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }

  Map<String, Object?> _requiredMap(Object? node, String name) {
    if (node is! Map) {
      throw FormatException('备份文件缺少 $name 对象');
    }
    return _stringKeyMap(node);
  }

  List<Map<String, Object?>> _mapList(Object? node, String name) {
    if (node == null) return const [];
    if (node is! List) {
      throw FormatException('备份文件 $name 必须是数组');
    }
    return [
      for (final item in node)
        if (item is Map)
          _stringKeyMap(item)
        else
          throw FormatException('$name 包含非对象节点')
    ];
  }

  Map<String, Object?> _stringKeyMap(Map map) {
    return map.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, Object?> _normalizePropertyMap(Map<String, Object?> map) {
    final normalized = Map<String, Object?>.of(map);
    final enumValues = normalized['enum_values'];
    if (enumValues is Map) {
      normalized['enum_values'] = jsonEncode(_stringKeyMap(enumValues));
    }
    normalized['enum_values'] ??= '{}';
    return normalized;
  }
}
