import '../storage/models.dart';

class ValueValidationResult {
  const ValueValidationResult({
    required this.isValid,
    required this.value,
    required this.message,
  });

  final bool isValid;
  final Object? value;
  final String message;

  static ValueValidationResult ok(Object? value) {
    return ValueValidationResult(isValid: true, value: value, message: '');
  }

  static ValueValidationResult fail(String message) {
    return ValueValidationResult(isValid: false, value: null, message: message);
  }
}

class ThingValueValidator {
  const ThingValueValidator();

  ValueValidationResult validateForControl(
      ThingProperty property, Object? rawValue) {
    if (!property.writable) {
      return ValueValidationResult.fail('${property.displayName} 是只读属性，不能下发控制');
    }
    switch (property.type) {
      case ThingDataType.int32:
      case ThingDataType.int64:
        return _validateInt(property, rawValue);
      case ThingDataType.float:
      case ThingDataType.doubleType:
        return _validateDouble(property, rawValue);
      case ThingDataType.boolType:
        return _validateBool(rawValue);
      case ThingDataType.enumType:
        return _validateEnum(property, rawValue);
      case ThingDataType.stringType:
        return ValueValidationResult.ok(rawValue?.toString() ?? '');
      case ThingDataType.struct:
      case ThingDataType.bitmap:
      case ThingDataType.unknown:
        return ValueValidationResult.fail('MVP 暂不支持下发 ${property.rawType} 类型');
    }
  }

  ValueValidationResult _validateInt(ThingProperty property, Object? rawValue) {
    final value =
        rawValue is int ? rawValue : int.tryParse(rawValue?.toString() ?? '');
    if (value == null) {
      return const ValueValidationResult(
          isValid: false, value: null, message: '请输入整数');
    }
    return _validateRange(property, value);
  }

  ValueValidationResult _validateDouble(
      ThingProperty property, Object? rawValue) {
    final value = rawValue is num
        ? rawValue.toDouble()
        : double.tryParse(rawValue?.toString() ?? '');
    if (value == null) {
      return const ValueValidationResult(
          isValid: false, value: null, message: '请输入数字');
    }
    return _validateRange(property, value);
  }

  ValueValidationResult _validateRange(ThingProperty property, num value) {
    if (property.min != null && value < property.min!) {
      return ValueValidationResult.fail('数值不能小于 ${property.min}');
    }
    if (property.max != null && value > property.max!) {
      return ValueValidationResult.fail('数值不能大于 ${property.max}');
    }
    return ValueValidationResult.ok(value);
  }

  ValueValidationResult _validateBool(Object? rawValue) {
    if (rawValue is bool) return ValueValidationResult.ok(rawValue);
    final text = rawValue?.toString().toLowerCase().trim();
    if (text == 'true' || text == '1' || text == 'on') {
      return ValueValidationResult.ok(true);
    }
    if (text == 'false' || text == '0' || text == 'off') {
      return ValueValidationResult.ok(false);
    }
    return ValueValidationResult.fail('请输入布尔值 true/false');
  }

  ValueValidationResult _validateEnum(
      ThingProperty property, Object? rawValue) {
    final value = rawValue?.toString() ?? '';
    if (property.enumValues.isEmpty || property.enumValues.containsKey(value)) {
      return ValueValidationResult.ok(value);
    }
    return ValueValidationResult.fail(
        '枚举值必须是: ${property.enumValues.keys.join(', ')}');
  }
}
