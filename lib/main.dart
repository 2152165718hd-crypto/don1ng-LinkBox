import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'dashboard/dashboard_widgets.dart';
import 'dashboard/icon_library.dart';
import 'onenet/onenet_mqtt_service.dart';
import 'onenet/token_log_parser.dart';
import 'runtime/linkbox_controller.dart';
import 'storage/models.dart';
import 'thing_model/thing_model_importer.dart';

final linkBoxControllerProvider =
    ChangeNotifierProvider<LinkBoxController>((ref) {
  final controller = LinkBoxController();
  controller.init();
  ref.onDispose(controller.dispose);
  return controller;
});

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LinkBoxApp()));
}

class LinkBoxApp extends StatelessWidget {
  const LinkBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'don1ng LinkBox',
      theme: LinkBoxTheme.light(),
      home: const _CoverGate(child: LinkBoxHomePage()),
    );
  }
}

class _CoverGate extends StatefulWidget {
  const _CoverGate({required this.child});

  final Widget child;

  @override
  State<_CoverGate> createState() => _CoverGateState();
}

class _CoverGateState extends State<_CoverGate> {
  bool _showCover = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1600), _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted || !_showCover) return;
    setState(() => _showCover = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_showCover) return widget.child;
    return Scaffold(
      backgroundColor: const Color(0xFF0E4D64),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/branding/linkbox_cover.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 28 + MediaQuery.of(context).padding.bottom,
              child: FilledButton.icon(
                onPressed: _dismiss,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('进入'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LinkBoxHomePage extends ConsumerStatefulWidget {
  const LinkBoxHomePage({super.key});

  @override
  ConsumerState<LinkBoxHomePage> createState() => _LinkBoxHomePageState();
}

class _LinkBoxHomePageState extends ConsumerState<LinkBoxHomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(linkBoxControllerProvider);
    final state = controller.state;
    final pages = [
      _ConfigScreen(controller: controller),
      _ThingModelScreen(controller: controller),
      _DashboardScreen(controller: controller),
      _RuntimeScreen(controller: controller),
      _LogsScreen(controller: controller),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('don1ng LinkBox'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _ConnectionChip(state: state)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.busy) const LinearProgressIndicator(minHeight: 2),
          if (state.statusText.isNotEmpty)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(state.statusText,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          Expanded(child: pages[_index]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '设备'),
          NavigationDestination(
              icon: Icon(Icons.dataset_outlined),
              selectedIcon: Icon(Icons.dataset),
              label: '物模型'),
          NavigationDestination(
            icon: Icon(Icons.dashboard_customize_outlined),
            selectedIcon: Icon(Icons.dashboard_customize),
            label: '面板',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: '运行',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '日志',
          ),
        ],
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.state});

  final LinkBoxState state;

  @override
  Widget build(BuildContext context) {
    final label = switch (state.connectionState) {
      OnenetMqttConnectionState.connected => '已连接',
      OnenetMqttConnectionState.connecting => '连接中',
      OnenetMqttConnectionState.failed => '连接失败',
      OnenetMqttConnectionState.disconnected => '未连接',
    };
    final color = switch (state.connectionState) {
      OnenetMqttConnectionState.connected => Colors.green,
      OnenetMqttConnectionState.connecting => Colors.orange,
      OnenetMqttConnectionState.failed => Colors.red,
      OnenetMqttConnectionState.disconnected => Colors.grey,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(Icons.circle, size: 10, color: color),
      label: Text(label),
    );
  }
}

class _ConfigScreen extends ConsumerStatefulWidget {
  const _ConfigScreen({required this.controller});

  final LinkBoxController controller;

  @override
  ConsumerState<_ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<_ConfigScreen> {
  final _projectId = TextEditingController();
  final _groupId = TextEditingController();
  final _userId = TextEditingController();
  final _accessKey = TextEditingController();
  final _productId = TextEditingController();
  final _deviceName = TextEditingController();
  final _refreshSeconds = TextEditingController();
  final _historyDays = TextEditingController();
  AuthMode _authMode = AuthMode.projectGroup;
  String _fingerprint = '';

  @override
  void dispose() {
    _projectId.dispose();
    _groupId.dispose();
    _userId.dispose();
    _accessKey.dispose();
    _productId.dispose();
    _deviceName.dispose();
    _refreshSeconds.dispose();
    _historyDays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    _syncControllers(state.config);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('OneNET Studio 应用接入',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                DropdownButtonFormField<AuthMode>(
                  initialValue: _authMode,
                  items: const [
                    DropdownMenuItem(
                        value: AuthMode.projectGroup, child: Text('项目分组鉴权')),
                    DropdownMenuItem(value: AuthMode.user, child: Text('用户鉴权')),
                  ],
                  onChanged: (value) => setState(
                      () => _authMode = value ?? AuthMode.projectGroup),
                  decoration: const InputDecoration(labelText: '鉴权模式'),
                ),
                const SizedBox(height: 10),
                _TextField(controller: _projectId, label: 'Project ID'),
                if (_authMode == AuthMode.projectGroup)
                  _TextField(controller: _groupId, label: 'Group ID'),
                if (_authMode == AuthMode.user)
                  _TextField(controller: _userId, label: 'User ID'),
                _TextField(
                    controller: _accessKey,
                    label: 'Access Key',
                    obscureText: true),
                _TextField(controller: _productId, label: 'Product ID'),
                _TextField(controller: _deviceName, label: 'Device Name'),
                Row(
                  children: [
                    Expanded(
                      child: _TextField(
                        controller: _refreshSeconds,
                        label: '刷新秒数',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TextField(
                        controller: _historyDays,
                        label: '历史天数',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('保存配置'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _importTokenLog,
                      icon: const Icon(Icons.description),
                      label: const Text('导入 Token.log'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.controller.connectRealtime,
                      icon: const Icon(Icons.link),
                      label: const Text('连接'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.controller.refreshLatest,
                      icon: const Icon(Icons.sync),
                      label: const Text('同步最新数据'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final file = await widget.controller.exportBackup();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已导出到 ${file.path}')));
                        }
                      },
                      icon: const Icon(Icons.ios_share),
                      label: const Text('导出配置'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _TutorialCard(),
      ],
    );
  }

  void _syncControllers(ProjectConfig config) {
    final nextFingerprint = [
      config.projectId,
      config.groupId,
      config.userId,
      config.accessKey,
      config.productId,
      config.deviceName,
      config.authMode.name,
      config.refreshSeconds,
      config.historyDays,
    ].join('|');
    if (_fingerprint == nextFingerprint) return;
    _fingerprint = nextFingerprint;
    _projectId.text = config.projectId;
    _groupId.text = config.groupId;
    _userId.text = config.userId;
    _accessKey.text = config.accessKey;
    _productId.text = config.productId;
    _deviceName.text = config.deviceName;
    _authMode = config.authMode;
    _refreshSeconds.text = config.refreshSeconds.toString();
    _historyDays.text = config.historyDays.toString();
  }

  Future<void> _save() async {
    final config = ProjectConfig(
      projectId: _projectId.text.trim(),
      groupId: _groupId.text.trim(),
      userId: _userId.text.trim(),
      accessKey: _accessKey.text.trim(),
      productId: _productId.text.trim(),
      deviceName: _deviceName.text.trim(),
      authMode: _authMode,
      refreshSeconds: int.tryParse(_refreshSeconds.text.trim()) ?? 15,
      historyDays: int.tryParse(_historyDays.text.trim()) ?? 7,
    );
    await widget.controller.saveConfig(config);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('配置已保存')));
    }
  }

  Future<void> _importTokenLog() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['log', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    try {
      final info = await TokenLogParser().parseBytes(Uint8List.fromList(bytes));
      setState(() {
        _productId.text = info.productId;
        _deviceName.text = info.deviceName;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '已从 Token.log 识别 Product ID 和 Device Name；DeviceKey 不会作为 APP AccessKey 使用'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Token.log 识别失败: $error')));
      }
    }
  }
}

class _ThingModelScreen extends StatelessWidget {
  const _ThingModelScreen({required this.controller});

  final LinkBoxController controller;

  @override
  Widget build(BuildContext context) {
    final properties = controller.state.properties;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => _importJson(context),
              icon: const Icon(Icons.upload_file),
              label: const Text('导入物模型 JSON'),
            ),
            OutlinedButton.icon(
              onPressed: controller.regenerateDashboard,
              icon: const Icon(Icons.auto_awesome_motion),
              label: const Text('补齐默认面板'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (properties.isEmpty)
          const _EmptyPanel(
            icon: Icons.dataset_outlined,
            title: '还没有物模型',
            message:
                '请导入 OneNET Studio 导出的 TSL JSON。导入后，每个属性会自动生成可编辑 UI 卡片，数值型属性会额外生成历史曲线。',
          )
        else
          ...properties.map((property) =>
              _PropertyTile(controller: controller, property: property)),
      ],
    );
  }

  Future<void> _importJson(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    try {
      final importResult =
          await controller.importThingModel(Uint8List.fromList(bytes));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '导入 ${importResult.properties.length} 个属性，跳过 ${importResult.skipped.length} 个'),
          ),
        );
        if (importResult.hasIssues) {
          showDialog<void>(
            context: context,
            builder: (_) => _ImportReportDialog(result: importResult),
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败: $error')));
      }
    }
  }
}

class _PropertyTile extends StatelessWidget {
  const _PropertyTile({
    required this.controller,
    required this.property,
  });

  final LinkBoxController controller;
  final ThingProperty property;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(property.displayName,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(_propertySubtitle(property),
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final widgetConfig =
                        await controller.dataWidgetForProperty(property);
                    if (context.mounted && widgetConfig != null) {
                      _openWidgetStyleEditor(
                          context, controller, property, widgetConfig);
                    }
                  },
                  icon: const Icon(Icons.tune),
                  label: const Text('配置 UI'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(label: Text(_typeLabel(property.type))),
                Chip(label: Text(_accessModeLabel(property.accessMode))),
                if (property.unit.isNotEmpty) Chip(label: Text(property.unit)),
                if (property.min != null || property.max != null)
                  Chip(
                      label: Text(
                          '${property.min ?? '-'} ~ ${property.max ?? '-'}')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen({required this.controller});

  final LinkBoxController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.state.widgets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: _EmptyPanel(
          icon: Icons.dashboard_customize_outlined,
          title: '还没有面板控件',
          message: '导入物模型后会自动生成可编辑 UI 卡片，也可以在物模型页补齐默认面板。',
        ),
      );
    }
    return _DashboardCanvas(controller: controller, editMode: true);
  }
}

class _RuntimeScreen extends StatelessWidget {
  const _RuntimeScreen({required this.controller});

  final LinkBoxController controller;

  @override
  Widget build(BuildContext context) {
    final propertyIds =
        controller.state.properties.map((item) => item.identifier).toSet();
    final widgets = controller.state.widgets
        .where((item) => propertyIds.contains(item.propertyIdentifier))
        .toList();
    if (widgets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: _EmptyPanel(
          icon: Icons.monitor_heart_outlined,
          title: '运行页未就绪',
          message: '请先导入物模型并生成面板。',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refreshLatest,
      child: _DashboardCanvas(
          controller: controller, editMode: false, alwaysScrollable: true),
    );
  }
}

class _DashboardCanvas extends StatelessWidget {
  const _DashboardCanvas({
    required this.controller,
    required this.editMode,
    this.alwaysScrollable = false,
  });

  final LinkBoxController controller;
  final bool editMode;
  final bool alwaysScrollable;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final propertyMap = {
      for (final property in state.properties) property.identifier: property
    };
    final widgets = state.widgets
        .where((item) => propertyMap.containsKey(item.propertyIdentifier))
        .toList();
    final physics =
        alwaysScrollable ? const AlwaysScrollableScrollPhysics() : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        var canvasWidth = constraints.maxWidth - 24;
        var canvasHeight = 360.0;
        for (final item in widgets) {
          final right = item.x + item.width + 16;
          final bottom = item.y + item.height + 16;
          if (right > canvasWidth) canvasWidth = right;
          if (bottom > canvasHeight) canvasHeight = bottom;
        }

        return SingleChildScrollView(
          physics: physics,
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: canvasWidth,
              height: canvasHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                    ),
                  ),
                  for (final item in widgets)
                    Positioned(
                      left: item.x,
                      top: item.y,
                      width: item.width,
                      height: item.height,
                      child: _DashboardTileFrame(
                        controller: controller,
                        config: item,
                        property: propertyMap[item.propertyIdentifier]!,
                        value: state.values[item.propertyIdentifier],
                        editMode: editMode,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardTileFrame extends StatelessWidget {
  const _DashboardTileFrame({
    required this.controller,
    required this.config,
    required this.property,
    required this.value,
    required this.editMode,
  });

  final LinkBoxController controller;
  final DashboardWidgetConfig config;
  final ThingProperty property;
  final RuntimeValue? value;
  final bool editMode;

  @override
  Widget build(BuildContext context) {
    final tile = DashboardTile(
      config: config,
      property: property,
      value: value,
      controller: controller,
      editMode: editMode,
      onEdit: () =>
          _openWidgetStyleEditor(context, controller, property, config),
      onDelete: () => controller.deleteWidget(config.id),
    );
    if (!editMode) return tile;
    return GestureDetector(
      onPanUpdate: (details) async {
        await controller.updateWidget(
          config.copyWith(
            x: (config.x + details.delta.dx).clamp(0, 1200).toDouble(),
            y: (config.y + details.delta.dy).clamp(0, 2400).toDouble(),
          ),
        );
      },
      child: tile,
    );
  }
}

class _LogsScreen extends StatelessWidget {
  const _LogsScreen({required this.controller});

  final LinkBoxController controller;

  @override
  Widget build(BuildContext context) {
    final logs = controller.state.logs;
    if (logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: _EmptyPanel(
          icon: Icons.receipt_long_outlined,
          title: '暂无运行日志',
          message: '连接、导入、控制和异常都会记录在这里。',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final log = logs[index];
        return ListTile(
          leading: Icon(_logIcon(log.level), color: _logColor(log.level)),
          title: Text(log.message),
          subtitle: Text(
              '${_formatDateTime(log.time)} · ${log.type}${log.detail.isEmpty ? '' : '\n${log.detail}'}'),
          isThreeLine: log.detail.isNotEmpty,
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: logs.length,
    );
  }
}

class _WidgetStyleSheet extends StatefulWidget {
  const _WidgetStyleSheet({
    required this.controller,
    required this.property,
    required this.initial,
  });

  final LinkBoxController controller;
  final ThingProperty property;
  final DashboardWidgetConfig initial;

  @override
  State<_WidgetStyleSheet> createState() => _WidgetStyleSheetState();
}

class _WidgetStyleSheetState extends State<_WidgetStyleSheet> {
  static const _backgroundOptions = [
    0xFFFFFFFF,
    0xFFF2F4F7,
    0xFFEFF8FF,
    0xFFF0FDF4,
    0xFFFFF7ED,
    0xFFFFF1F2,
    0xFF101828,
  ];
  static const _textOptions = [
    0xFF101828,
    0xFF175CD3,
    0xFF067647,
    0xFFB54708,
    0xFFC01048,
    0xFFFFFFFF,
  ];

  late final TextEditingController _title;
  late final TextEditingController _width;
  late final TextEditingController _height;
  late final TextEditingController _decimalDigits;
  late DashboardDisplayMode _displayMode;
  late DashboardIconKind _iconKind;
  late String _iconValue;
  late bool _showUnit;
  late int _backgroundColor;
  late int _textColor;
  bool _savingIcon = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial.title);
    _width =
        TextEditingController(text: widget.initial.width.round().toString());
    _height =
        TextEditingController(text: widget.initial.height.round().toString());
    _decimalDigits =
        TextEditingController(text: widget.initial.decimalDigits.toString());
    _displayMode = widget.initial.displayMode;
    _iconKind = widget.initial.iconKind;
    _iconValue = widget.initial.iconValue;
    _showUnit = widget.initial.showUnit;
    _backgroundColor = widget.initial.backgroundColor;
    _textColor = widget.initial.textColor;
  }

  @override
  void dispose() {
    _title.dispose();
    _width.dispose();
    _height.dispose();
    _decimalDigits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modes = _allowedModes();
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('配置 UI',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: '关闭',
                  ),
                ],
              ),
              Text(widget.property.displayName,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<DashboardDisplayMode>(
                initialValue: _displayMode,
                isExpanded: true,
                items: modes
                    .map((mode) => DropdownMenuItem(
                        value: mode, child: Text(_displayModeLabel(mode))))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _displayMode = value);
                },
                decoration: const InputDecoration(labelText: '显示类型'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _width,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '宽度'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _height,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '高度'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                value: _showUnit,
                onChanged: (value) => setState(() => _showUnit = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('显示单位'),
              ),
              if (widget.property.isNumeric)
                TextField(
                  controller: _decimalDigits,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '小数位'),
                ),
              const SizedBox(height: 10),
              DropdownButtonFormField<DashboardIconKind>(
                initialValue: _iconKind,
                items: DashboardIconKind.values
                    .map((kind) => DropdownMenuItem(
                        value: kind, child: Text(_iconKindLabel(kind))))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _iconKind = value;
                    if (_iconKind == DashboardIconKind.material &&
                        _iconValue.isEmpty) {
                      _iconValue = LinkBoxIconLibrary.materialIcons.first.key;
                    }
                    if (_iconKind == DashboardIconKind.builtinPng &&
                        _iconValue.isEmpty) {
                      _iconValue = LinkBoxIconLibrary.builtinPngIcons.last.key;
                    }
                  });
                },
                decoration: const InputDecoration(labelText: '图标来源'),
              ),
              const SizedBox(height: 10),
              _IconValueEditor(
                kind: _iconKind,
                value: _iconValue,
                saving: _savingIcon,
                onChanged: (value) => setState(() => _iconValue = value),
                onUpload: _pickPng,
              ),
              const SizedBox(height: 14),
              _ColorPickerRow(
                title: '卡片背景',
                value: _backgroundColor,
                options: _backgroundOptions,
                onChanged: (value) => setState(() => _backgroundColor = value),
              ),
              const SizedBox(height: 12),
              _ColorPickerRow(
                title: '文字颜色',
                value: _textColor,
                options: _textOptions,
                onChanged: (value) => setState(() => _textColor = value),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DashboardDisplayMode> _allowedModes() {
    final modes = widget.initial.displayMode == DashboardDisplayMode.trendChart
        ? <DashboardDisplayMode>[DashboardDisplayMode.trendChart]
        : compatibleDisplayModes(widget.property)
            .where((mode) => mode != DashboardDisplayMode.trendChart)
            .toList();
    if (!modes.contains(_displayMode)) {
      modes.add(_displayMode);
    }
    return modes;
  }

  Future<void> _pickPng() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    final bytes =
        file.bytes ?? (path == null ? null : await File(path).readAsBytes());
    if (bytes == null) return;
    setState(() => _savingIcon = true);
    final savedPath = await widget.controller.saveUploadedIcon(
      bytes: Uint8List.fromList(bytes),
      originalName: file.name,
    );
    if (!mounted) return;
    setState(() {
      _savingIcon = false;
      _iconKind = DashboardIconKind.uploadedPng;
      _iconValue = savedPath;
    });
  }

  Future<void> _save() async {
    final width = (double.tryParse(_width.text.trim()) ?? widget.initial.width)
        .clamp(96, 720)
        .toDouble();
    final height =
        (double.tryParse(_height.text.trim()) ?? widget.initial.height)
            .clamp(80, 520)
            .toDouble();
    final decimalDigits = (int.tryParse(_decimalDigits.text.trim()) ??
            widget.initial.decimalDigits)
        .clamp(0, 6)
        .toInt();
    final updated = widget.initial.copyWith(
      title: _title.text.trim().isEmpty
          ? widget.property.displayName
          : _title.text.trim(),
      width: width,
      height: height,
      displayMode: _displayMode,
      type: widgetTypeForDisplayMode(_displayMode),
      iconKind: _iconKind,
      iconValue: _iconValue,
      showUnit: _showUnit,
      decimalDigits: decimalDigits,
      backgroundColor: _backgroundColor,
      textColor: _textColor,
    );
    await widget.controller.updateWidget(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('UI 配置已保存')));
  }
}

class _IconValueEditor extends StatelessWidget {
  const _IconValueEditor({
    required this.kind,
    required this.value,
    required this.saving,
    required this.onChanged,
    required this.onUpload,
  });

  final DashboardIconKind kind;
  final String value;
  final bool saving;
  final ValueChanged<String> onChanged;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case DashboardIconKind.none:
        return const SizedBox.shrink();
      case DashboardIconKind.material:
        final current =
            LinkBoxIconLibrary.materialIcons.any((item) => item.key == value)
                ? value
                : LinkBoxIconLibrary.materialIcons.first.key;
        return DropdownButtonFormField<String>(
          initialValue: current,
          items: LinkBoxIconLibrary.materialIcons
              .map(
                (item) => DropdownMenuItem(
                  value: item.key,
                  child: Row(
                    children: [
                      Icon(item.icon, size: 20),
                      const SizedBox(width: 8),
                      Text(item.label),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
          decoration: const InputDecoration(labelText: 'Material 矢量图标'),
        );
      case DashboardIconKind.builtinPng:
        final current =
            LinkBoxIconLibrary.builtinPngIcons.any((item) => item.key == value)
                ? value
                : LinkBoxIconLibrary.builtinPngIcons.last.key;
        return DropdownButtonFormField<String>(
          initialValue: current,
          items: LinkBoxIconLibrary.builtinPngIcons
              .map(
                (item) => DropdownMenuItem(
                  value: item.key,
                  child: Row(
                    children: [
                      Image.asset(item.asset, width: 22, height: 22),
                      const SizedBox(width: 8),
                      Text(item.label),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
          decoration: const InputDecoration(labelText: '内置 PNG 图库'),
        );
      case DashboardIconKind.uploadedPng:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: saving ? null : onUpload,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.image),
              label: Text(value.isEmpty ? '上传 PNG 图标' : '更换 PNG 图标'),
            ),
            if (value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        );
    }
  }
}

class _ColorPickerRow extends StatelessWidget {
  const _ColorPickerRow({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                selected: value == option,
                onSelected: (_) => onChanged(option),
                label: const SizedBox(width: 24, height: 18),
                avatar: CircleAvatar(backgroundColor: Color(option)),
              ),
          ],
        ),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _TutorialCard extends StatelessWidget {
  const _TutorialCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最短接入路径', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('1. 在 OneNET Studio 创建产品和设备，接入协议选择 MQTT。'),
            const Text('2. 设置物模型并导出 JSON，在物模型页导入。'),
            const Text('3. 在应用开发中创建项目分组，复制 Project ID、Group ID 和 AccessKey。'),
            const Text('4. 保存配置后点击连接，先同步最新数据，再进入运行页调试。'),
            const SizedBox(height: 8),
            Text(
              'MVP 使用应用长连接和 OpenAPI，不占用单片机设备的 MQTT 登录身份。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 42, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportReportDialog extends StatelessWidget {
  const _ImportReportDialog({required this.result});

  final ThingModelImportResult result;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导入报告'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final warning in result.warnings) Text('提示: $warning'),
            for (final skipped in result.skipped)
              Text('跳过 ${skipped.identifier}: ${skipped.reason}'),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了')),
      ],
    );
  }
}

void _openWidgetStyleEditor(
  BuildContext context,
  LinkBoxController controller,
  ThingProperty property,
  DashboardWidgetConfig config,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _WidgetStyleSheet(
      controller: controller,
      property: property,
      initial: config,
    ),
  );
}

String _propertySubtitle(ThingProperty property) {
  return '${property.identifier} · ${property.rawType} · ${_accessModeLabel(property.accessMode)}';
}

String _accessModeLabel(AccessMode mode) {
  return switch (mode) {
    AccessMode.readOnly => '只读',
    AccessMode.writeOnly => '只写',
    AccessMode.readWrite => '读写',
  };
}

String _typeLabel(ThingDataType type) {
  return switch (type) {
    ThingDataType.int32 => 'int32',
    ThingDataType.int64 => 'int64',
    ThingDataType.float => 'float',
    ThingDataType.doubleType => 'double',
    ThingDataType.boolType => 'bool',
    ThingDataType.enumType => 'enum',
    ThingDataType.stringType => 'string',
    ThingDataType.struct => 'struct',
    ThingDataType.bitmap => 'bitmap',
    ThingDataType.unknown => 'unknown',
  };
}

String _displayModeLabel(DashboardDisplayMode mode) {
  return switch (mode) {
    DashboardDisplayMode.value => '数值卡',
    DashboardDisplayMode.progress => '进度条',
    DashboardDisplayMode.slider => '滑块控制',
    DashboardDisplayMode.gauge => '仪表风格',
    DashboardDisplayMode.switcher => '开关',
    DashboardDisplayMode.button => '按钮',
    DashboardDisplayMode.enumSelect => '下拉选择',
    DashboardDisplayMode.status => '状态卡',
    DashboardDisplayMode.text => '文本卡',
    DashboardDisplayMode.trendChart => '历史曲线',
  };
}

String _iconKindLabel(DashboardIconKind kind) {
  return switch (kind) {
    DashboardIconKind.none => '无图标',
    DashboardIconKind.material => 'Material 矢量图标',
    DashboardIconKind.builtinPng => '内置 PNG 图库',
    DashboardIconKind.uploadedPng => '上传 PNG',
  };
}

IconData _logIcon(LogLevel level) {
  return switch (level) {
    LogLevel.info => Icons.info_outline,
    LogLevel.warning => Icons.warning_amber,
    LogLevel.error => Icons.error_outline,
  };
}

Color _logColor(LogLevel level) {
  return switch (level) {
    LogLevel.info => Colors.blueGrey,
    LogLevel.warning => Colors.orange,
    LogLevel.error => Colors.red,
  };
}

String _formatDateTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}
