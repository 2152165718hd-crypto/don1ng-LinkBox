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

class BuiltinSvgIcon {
  const BuiltinSvgIcon({
    required this.key,
    required this.label,
    required this.asset,
    required this.category,
    this.keywords = const [],
  });

  final String key;
  final String label;
  final String asset;
  final String category;
  final List<String> keywords;
}

class MaterialIconOption {
  const MaterialIconOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.category,
    this.keywords = const [],
  });

  final String key;
  final String label;
  final IconData icon;
  final String category;
  final List<String> keywords;
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

  static const builtinSvgIcons = [
    BuiltinSvgIcon(
      key: 'svg_device',
      label: '默认设备',
      asset: 'assets/vector_icons/device.svg',
      category: '设备',
      keywords: ['device', 'node', '设备', '终端'],
    ),
    BuiltinSvgIcon(
      key: 'svg_temperature',
      label: '温度',
      asset: 'assets/vector_icons/temperature.svg',
      category: '环境',
      keywords: ['temp', 'thermostat', '温度'],
    ),
    BuiltinSvgIcon(
      key: 'svg_humidity',
      label: '湿度',
      asset: 'assets/vector_icons/humidity.svg',
      category: '环境',
      keywords: ['hum', 'water', '湿度'],
    ),
    BuiltinSvgIcon(
      key: 'svg_light',
      label: '光照',
      asset: 'assets/vector_icons/light.svg',
      category: '环境',
      keywords: ['light', 'illum', 'lux', '光照'],
    ),
    BuiltinSvgIcon(
      key: 'svg_smoke',
      label: '烟雾',
      asset: 'assets/vector_icons/smoke.svg',
      category: '环境',
      keywords: ['smoke', 'gas', '烟雾', '气体'],
    ),
    BuiltinSvgIcon(
      key: 'svg_distance',
      label: '距离',
      asset: 'assets/vector_icons/distance.svg',
      category: '测量',
      keywords: ['distance', 'range', '距离'],
    ),
    BuiltinSvgIcon(
      key: 'svg_switch',
      label: '开关',
      asset: 'assets/vector_icons/switch.svg',
      category: '控制',
      keywords: ['switch', 'led', '开关'],
    ),
    BuiltinSvgIcon(
      key: 'svg_relay',
      label: '继电器',
      asset: 'assets/vector_icons/relay.svg',
      category: '控制',
      keywords: ['relay', '继电器'],
    ),
    BuiltinSvgIcon(
      key: 'svg_motor',
      label: '电机',
      asset: 'assets/vector_icons/motor.svg',
      category: '工业',
      keywords: ['motor', '电机'],
    ),
    BuiltinSvgIcon(
      key: 'svg_gateway',
      label: '网关',
      asset: 'assets/vector_icons/gateway.svg',
      category: '网络',
      keywords: ['gateway', 'router', '网关'],
    ),
    BuiltinSvgIcon(
      key: 'svg_fan',
      label: '风扇',
      asset: 'assets/vector_icons/fan.svg',
      category: '工业',
      keywords: ['fan', 'air', '风扇'],
    ),
    BuiltinSvgIcon(
      key: 'svg_pump',
      label: '水泵',
      asset: 'assets/vector_icons/pump.svg',
      category: '工业',
      keywords: ['pump', 'water', '水泵'],
    ),
    BuiltinSvgIcon(
      key: 'svg_valve',
      label: '阀门',
      asset: 'assets/vector_icons/valve.svg',
      category: '工业',
      keywords: ['valve', '阀门'],
    ),
    BuiltinSvgIcon(
      key: 'svg_battery',
      label: '电池',
      asset: 'assets/vector_icons/battery.svg',
      category: '电源',
      keywords: ['battery', 'power', '电池'],
    ),
    BuiltinSvgIcon(
      key: 'svg_camera',
      label: '摄像头',
      asset: 'assets/vector_icons/camera.svg',
      category: '设备',
      keywords: ['camera', 'video', '摄像头'],
    ),
    BuiltinSvgIcon(
      key: 'svg_lock',
      label: '门锁',
      asset: 'assets/vector_icons/lock.svg',
      category: '安全',
      keywords: ['lock', 'door', '门锁'],
    ),
  ];

  static const materialIcons = [
    MaterialIconOption(
        key: 'sensors', label: '传感器', icon: Icons.sensors, category: '环境'),
    MaterialIconOption(
        key: 'thermostat', label: '温度', icon: Icons.thermostat, category: '环境'),
    MaterialIconOption(
        key: 'water_drop', label: '湿度', icon: Icons.water_drop, category: '环境'),
    MaterialIconOption(
        key: 'wb_sunny', label: '光照', icon: Icons.wb_sunny, category: '环境'),
    MaterialIconOption(
        key: 'cloud', label: '烟雾', icon: Icons.cloud, category: '环境'),
    MaterialIconOption(
        key: 'air', label: '空气', icon: Icons.air, category: '环境'),
    MaterialIconOption(
        key: 'ac_unit', label: '制冷', icon: Icons.ac_unit, category: '环境'),
    MaterialIconOption(
        key: 'local_fire_department',
        label: '火焰',
        icon: Icons.local_fire_department,
        category: '环境'),
    MaterialIconOption(
        key: 'opacity', label: '液体', icon: Icons.opacity, category: '环境'),
    MaterialIconOption(
        key: 'devices', label: '终端', icon: Icons.devices, category: '设备'),
    MaterialIconOption(
        key: 'router', label: '路由器', icon: Icons.router, category: '设备'),
    MaterialIconOption(
        key: 'settings_remote',
        label: '遥控器',
        icon: Icons.settings_remote,
        category: '设备'),
    MaterialIconOption(
        key: 'hub', label: '网关', icon: Icons.hub, category: '设备'),
    MaterialIconOption(
        key: 'cable', label: '线缆', icon: Icons.cable, category: '设备'),
    MaterialIconOption(
        key: 'memory', label: '芯片', icon: Icons.memory, category: '设备'),
    MaterialIconOption(
        key: 'camera_alt',
        label: '摄像头',
        icon: Icons.camera_alt,
        category: '设备'),
    MaterialIconOption(
        key: 'videocam', label: '视频', icon: Icons.videocam, category: '设备'),
    MaterialIconOption(
        key: 'mic', label: '麦克风', icon: Icons.mic, category: '设备'),
    MaterialIconOption(
        key: 'wifi', label: 'Wi-Fi', icon: Icons.wifi, category: '网络'),
    MaterialIconOption(
        key: 'bluetooth', label: '蓝牙', icon: Icons.bluetooth, category: '网络'),
    MaterialIconOption(
        key: 'lan', label: '局域网', icon: Icons.lan, category: '网络'),
    MaterialIconOption(
        key: 'link', label: '连接', icon: Icons.link, category: '网络'),
    MaterialIconOption(
        key: 'sync', label: '同步', icon: Icons.sync, category: '网络'),
    MaterialIconOption(
        key: 'cloud_sync',
        label: '云同步',
        icon: Icons.cloud_sync,
        category: '网络'),
    MaterialIconOption(
        key: 'qr_code_2', label: '二维码', icon: Icons.qr_code_2, category: '网络'),
    MaterialIconOption(
        key: 'power_settings_new',
        label: '电源',
        icon: Icons.power_settings_new,
        category: '电源'),
    MaterialIconOption(
        key: 'power', label: '供电', icon: Icons.power, category: '电源'),
    MaterialIconOption(
        key: 'battery_full',
        label: '电池',
        icon: Icons.battery_full,
        category: '电源'),
    MaterialIconOption(
        key: 'battery_charging_full',
        label: '充电',
        icon: Icons.battery_charging_full,
        category: '电源'),
    MaterialIconOption(
        key: 'flash_on', label: '闪电', icon: Icons.flash_on, category: '电源'),
    MaterialIconOption(
        key: 'bolt', label: '能耗', icon: Icons.bolt, category: '电源'),
    MaterialIconOption(
        key: 'lightbulb', label: '灯泡', icon: Icons.lightbulb, category: '电源'),
    MaterialIconOption(
        key: 'warning_amber',
        label: '告警',
        icon: Icons.warning_amber,
        category: '状态'),
    MaterialIconOption(
        key: 'error_outline',
        label: '异常',
        icon: Icons.error_outline,
        category: '状态'),
    MaterialIconOption(
        key: 'check_circle',
        label: '正常',
        icon: Icons.check_circle,
        category: '状态'),
    MaterialIconOption(
        key: 'cancel', label: '关闭', icon: Icons.cancel, category: '状态'),
    MaterialIconOption(
        key: 'info_outline',
        label: '信息',
        icon: Icons.info_outline,
        category: '状态'),
    MaterialIconOption(
        key: 'notifications',
        label: '通知',
        icon: Icons.notifications,
        category: '状态'),
    MaterialIconOption(
        key: 'security', label: '安全', icon: Icons.security, category: '状态'),
    MaterialIconOption(
        key: 'shield', label: '防护', icon: Icons.shield, category: '状态'),
    MaterialIconOption(
        key: 'factory', label: '工厂', icon: Icons.factory, category: '工业'),
    MaterialIconOption(
        key: 'apartment', label: '楼宇', icon: Icons.apartment, category: '工业'),
    MaterialIconOption(
        key: 'precision_manufacturing',
        label: '制造',
        icon: Icons.precision_manufacturing,
        category: '工业'),
    MaterialIconOption(
        key: 'build', label: '维护', icon: Icons.build, category: '工业'),
    MaterialIconOption(
        key: 'construction',
        label: '施工',
        icon: Icons.construction,
        category: '工业'),
    MaterialIconOption(
        key: 'engineering',
        label: '工程',
        icon: Icons.engineering,
        category: '工业'),
    MaterialIconOption(
        key: 'plumbing', label: '管路', icon: Icons.plumbing, category: '工业'),
    MaterialIconOption(
        key: 'settings_input_component',
        label: '电机',
        icon: Icons.settings_input_component,
        category: '工业'),
    MaterialIconOption(
        key: 'speed', label: '速度', icon: Icons.speed, category: '数据'),
    MaterialIconOption(
        key: 'straighten', label: '距离', icon: Icons.straighten, category: '数据'),
    MaterialIconOption(
        key: 'timeline', label: '趋势', icon: Icons.timeline, category: '数据'),
    MaterialIconOption(
        key: 'show_chart', label: '曲线', icon: Icons.show_chart, category: '数据'),
    MaterialIconOption(
        key: 'analytics', label: '分析', icon: Icons.analytics, category: '数据'),
    MaterialIconOption(
        key: 'tune', label: '调节', icon: Icons.tune, category: '操作'),
    MaterialIconOption(
        key: 'dashboard', label: '面板', icon: Icons.dashboard, category: '操作'),
    MaterialIconOption(
        key: 'toggle_on', label: '开关', icon: Icons.toggle_on, category: '操作'),
  ];

  static int get vectorIconCount =>
      materialIcons.length + builtinSvgIcons.length;

  static BuiltinPngIcon builtinByKey(String key) {
    return builtinPngIcons.firstWhere(
      (item) => item.key == key,
      orElse: () => builtinPngIcons.last,
    );
  }

  static BuiltinSvgIcon builtinSvgByKey(String key) {
    return builtinSvgIcons.firstWhere(
      (item) => item.key == key,
      orElse: () => builtinSvgIcons.first,
    );
  }

  static MaterialIconOption materialByKey(String key) {
    return materialIcons.firstWhere(
      (item) => item.key == key,
      orElse: () => materialIcons.first,
    );
  }
}
