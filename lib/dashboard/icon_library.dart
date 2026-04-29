import 'package:flutter/material.dart';

class BuiltinPngIcon {
  const BuiltinPngIcon({
    required this.key,
    required this.label,
    required this.asset,
  });

  final String key;
  final String label;
  final String asset;
}

class MaterialIconOption {
  const MaterialIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

class LinkBoxIconLibrary {
  const LinkBoxIconLibrary._();

  static const builtinPngIcons = [
    BuiltinPngIcon(
        key: 'temperature',
        label: '温度',
        asset: 'assets/iot_icons/temperature.png'),
    BuiltinPngIcon(
        key: 'humidity', label: '湿度', asset: 'assets/iot_icons/humidity.png'),
    BuiltinPngIcon(
        key: 'light', label: '光照', asset: 'assets/iot_icons/light.png'),
    BuiltinPngIcon(
        key: 'smoke', label: '烟雾', asset: 'assets/iot_icons/smoke.png'),
    BuiltinPngIcon(
        key: 'distance', label: '距离', asset: 'assets/iot_icons/distance.png'),
    BuiltinPngIcon(
        key: 'switch', label: '开关', asset: 'assets/iot_icons/switch.png'),
    BuiltinPngIcon(
        key: 'relay', label: '继电器', asset: 'assets/iot_icons/relay.png'),
    BuiltinPngIcon(
        key: 'motor', label: '电机', asset: 'assets/iot_icons/motor.png'),
    BuiltinPngIcon(
        key: 'device', label: '默认设备', asset: 'assets/iot_icons/device.png'),
  ];

  static const materialIcons = [
    MaterialIconOption(key: 'sensors', label: '传感器', icon: Icons.sensors),
    MaterialIconOption(key: 'thermostat', label: '温度', icon: Icons.thermostat),
    MaterialIconOption(key: 'water_drop', label: '湿度', icon: Icons.water_drop),
    MaterialIconOption(key: 'wb_sunny', label: '光照', icon: Icons.wb_sunny),
    MaterialIconOption(key: 'cloud', label: '烟雾', icon: Icons.cloud),
    MaterialIconOption(key: 'straighten', label: '距离', icon: Icons.straighten),
    MaterialIconOption(key: 'toggle_on', label: '开关', icon: Icons.toggle_on),
    MaterialIconOption(
        key: 'power_settings_new',
        label: '继电器',
        icon: Icons.power_settings_new),
    MaterialIconOption(
        key: 'settings_input_component',
        label: '电机',
        icon: Icons.settings_input_component),
    MaterialIconOption(key: 'memory', label: '芯片', icon: Icons.memory),
  ];

  static BuiltinPngIcon builtinByKey(String key) {
    return builtinPngIcons.firstWhere(
      (item) => item.key == key,
      orElse: () => builtinPngIcons.last,
    );
  }

  static MaterialIconOption materialByKey(String key) {
    return materialIcons.firstWhere(
      (item) => item.key == key,
      orElse: () => materialIcons.first,
    );
  }
}
