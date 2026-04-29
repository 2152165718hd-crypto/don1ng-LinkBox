import 'package:don1ng_linkbox/storage/models.dart';
import 'package:don1ng_linkbox/thing_model/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects out-of-range control values', () {
    const property = ThingProperty(
      identifier: 'DCMotor',
      name: '直流电机速度',
      type: ThingDataType.int32,
      accessMode: AccessMode.readWrite,
      min: 0,
      max: 100,
      rawType: 'int32',
    );

    final validator = const ThingValueValidator();

    expect(validator.validateForControl(property, 80).isValid, isTrue);
    expect(validator.validateForControl(property, 120).isValid, isFalse);
  });

  test('rejects writes to read-only properties', () {
    const property = ThingProperty(
      identifier: 'Temp',
      name: '温度',
      type: ThingDataType.float,
      accessMode: AccessMode.readOnly,
      rawType: 'float',
    );

    final result =
        const ThingValueValidator().validateForControl(property, 20.5);

    expect(result.isValid, isFalse);
    expect(result.message, contains('只读'));
  });
}
