import 'dart:convert';
import 'dart:typed_data';

import '../storage/models.dart';

class ThingModelSkippedItem {
  const ThingModelSkippedItem({
    required this.identifier,
    required this.reason,
  });

  final String identifier;
  final String reason;
}

class ThingModelImportResult {
  const ThingModelImportResult({
    required this.properties,
    required this.skipped,
    required this.warnings,
    this.productId = '',
  });

  final List<ThingProperty> properties;
  final List<ThingModelSkippedItem> skipped;
  final List<String> warnings;
  final String productId;

  bool get hasIssues => skipped.isNotEmpty || warnings.isNotEmpty;
}

class ThingModelImporter {
  Future<ThingModelImportResult> importBytes(Uint8List bytes) async {
    final warnings = <String>[];
    final text = await _decodeText(bytes, warnings);
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('物模型文件根节点必须是 JSON 对象');
    }
    final propertiesNode = decoded['properties'];
    if (propertiesNode is! List) {
      throw const FormatException('未找到 OneNET 物模型 properties 数组');
    }
    final productId = _readProductId(decoded);
    final imported = <ThingProperty>[];
    final skipped = <ThingModelSkippedItem>[];

    for (final item in propertiesNode) {
      if (item is! Map) {
        skipped.add(
            const ThingModelSkippedItem(identifier: '-', reason: '属性节点不是对象'));
        continue;
      }
      final identifier = item['identifier']?.toString().trim() ?? '';
      try {
        imported.add(_parseProperty(item));
      } on FormatException catch (error) {
        skipped.add(
          ThingModelSkippedItem(
            identifier: identifier.isEmpty ? '-' : identifier,
            reason: error.message,
          ),
        );
      }
    }

    if (text.contains('�') || text.contains('锟')) {
      warnings.add('检测到疑似乱码字符，请确认物模型文件是 OneNET 导出的 UTF-8 JSON。');
    }

    return ThingModelImportResult(
      properties: imported,
      skipped: skipped,
      warnings: warnings,
      productId: productId,
    );
  }

  String _readProductId(Map root) {
    final profile = root['profile'];
    if (profile is Map) {
      return profile['productId']?.toString().trim() ?? '';
    }
    return '';
  }

  Future<String> _decodeText(Uint8List bytes, List<String> warnings) async {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      warnings.add('文件不是标准 UTF-8，已使用容错解码；如果中文异常，请从 OneNET 重新导出 UTF-8 JSON。');
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  ThingProperty _parseProperty(Map item) {
    final identifier = item['identifier']?.toString().trim() ?? '';
    if (identifier.isEmpty) {
      throw const FormatException('缺少属性标识符 identifier');
    }
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,63}$').hasMatch(identifier)) {
      throw const FormatException('identifier 只能由字母、数字、下划线组成，且不能以数字开头');
    }
    final dataTypeNode = item['dataType'];
    if (dataTypeNode is! Map) {
      throw const FormatException('缺少 dataType 对象');
    }
    final rawType = dataTypeNode['type']?.toString() ?? '';
    final specs =
        dataTypeNode['specs'] is Map ? dataTypeNode['specs'] as Map : const {};
    final type = _mapType(rawType);
    if (type == ThingDataType.unknown) {
      throw FormatException('暂不支持的数据类型 $rawType');
    }

    return ThingProperty(
      identifier: identifier,
      name: item['name']?.toString() ?? identifier,
      description: item['desc']?.toString() ?? '',
      type: type,
      accessMode: _mapAccessMode(item['accessMode']?.toString() ?? 'r'),
      unit: specs['unit']?.toString() ?? '',
      min: _parseNum(specs['min']),
      max: _parseNum(specs['max']),
      step: _parseNum(specs['step']),
      enumValues:
          type == ThingDataType.enumType ? _parseEnumValues(specs) : const {},
      rawType: rawType,
      required: item['required'] == true,
    );
  }

  ThingDataType _mapType(String raw) {
    switch (raw.toLowerCase()) {
      case 'int':
      case 'int32':
        return ThingDataType.int32;
      case 'long':
      case 'int64':
        return ThingDataType.int64;
      case 'float':
        return ThingDataType.float;
      case 'double':
        return ThingDataType.doubleType;
      case 'bool':
      case 'boolean':
        return ThingDataType.boolType;
      case 'enum':
        return ThingDataType.enumType;
      case 'string':
        return ThingDataType.stringType;
      case 'struct':
        return ThingDataType.struct;
      case 'bitmap':
      case 'bitMap':
        return ThingDataType.bitmap;
      default:
        return ThingDataType.unknown;
    }
  }

  AccessMode _mapAccessMode(String raw) {
    switch (raw.toLowerCase()) {
      case 'rw':
      case 'readwrite':
      case '读写':
        return AccessMode.readWrite;
      case 'w':
      case 'write':
      case '只写':
        return AccessMode.writeOnly;
      default:
        return AccessMode.readOnly;
    }
  }

  num? _parseNum(Object? value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  Map<String, String> _parseEnumValues(Map specs) {
    const reservedKeys = {
      'min',
      'max',
      'step',
      'unit',
      'length',
      'minLength',
      'maxLength',
      'default',
    };
    final enumMap = <String, String>{};
    for (final entry in specs.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (reservedKeys.contains(key)) continue;
      if (value is Map && value['name'] != null) {
        enumMap[key] = value['name'].toString();
      } else {
        enumMap[key] = value.toString();
      }
    }
    return enumMap;
  }
}
