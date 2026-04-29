import '../storage/models.dart';

class GraduateThingTemplates {
  const GraduateThingTemplates._();

  static List<ThingProperty> all() {
    return const [
      ThingProperty(
        identifier: 'Temp',
        name: '温度',
        type: ThingDataType.float,
        accessMode: AccessMode.readOnly,
        unit: '°C',
        min: -40,
        max: 125,
        rawType: 'float',
      ),
      ThingProperty(
        identifier: 'Hum',
        name: '湿度',
        type: ThingDataType.float,
        accessMode: AccessMode.readOnly,
        unit: '%RH',
        min: 0,
        max: 100,
        rawType: 'float',
      ),
      ThingProperty(
        identifier: 'Smoke',
        name: '烟雾浓度',
        type: ThingDataType.int32,
        accessMode: AccessMode.readOnly,
        unit: 'ppm',
        min: 0,
        max: 10000,
        rawType: 'int32',
      ),
      ThingProperty(
        identifier: 'PIR',
        name: '人体红外',
        type: ThingDataType.boolType,
        accessMode: AccessMode.readOnly,
        rawType: 'bool',
      ),
      ThingProperty(
        identifier: 'Light',
        name: '光照强度',
        type: ThingDataType.int32,
        accessMode: AccessMode.readOnly,
        unit: 'Lux',
        min: 0,
        max: 65535,
        rawType: 'int32',
      ),
      ThingProperty(
        identifier: 'Distance',
        name: '超声波距离',
        type: ThingDataType.float,
        accessMode: AccessMode.readOnly,
        unit: 'cm',
        min: 0,
        max: 500,
        rawType: 'float',
      ),
      ThingProperty(
        identifier: 'Relay',
        name: '继电器',
        type: ThingDataType.boolType,
        accessMode: AccessMode.readWrite,
        rawType: 'bool',
      ),
      ThingProperty(
        identifier: 'LED',
        name: 'LED灯',
        type: ThingDataType.boolType,
        accessMode: AccessMode.readWrite,
        rawType: 'bool',
      ),
      ThingProperty(
        identifier: 'DCMotor',
        name: '直流电机速度',
        type: ThingDataType.int32,
        accessMode: AccessMode.readWrite,
        unit: '%',
        min: 0,
        max: 100,
        step: 1,
        rawType: 'int32',
      ),
      ThingProperty(
        identifier: 'Stepper',
        name: '步进电机角度',
        type: ThingDataType.int32,
        accessMode: AccessMode.readWrite,
        unit: '°',
        min: 0,
        max: 360,
        step: 1,
        rawType: 'int32',
      ),
    ];
  }
}
