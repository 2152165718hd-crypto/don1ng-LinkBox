import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'dashboard/dashboard_widgets.dart';
import 'onenet/onenet_mqtt_service.dart';
import 'onenet/token_log_parser.dart';
import 'runtime/linkbox_controller.dart';
import 'storage/models.dart';
import 'thing_model/thing_model_importer.dart';

final linkBoxControllerProvider = ChangeNotifierProvider<LinkBoxController>((ref) {
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
              child: Text(state.statusText, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          Expanded(child: pages[_index]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设备'),
          NavigationDestination(icon: Icon(Icons.dataset_outlined), selectedIcon: Icon(Icons.dataset), label: '物模型'),
          NavigationDestination(icon: Icon(Icons.dashboard_customize_outlined), selectedIcon: Icon(Icons.dashboard_customize), label: '面板'),
          NavigationDestination(icon: Icon(Icons.monitor_heart_outlined), selectedIcon: Icon(Icons.monitor_heart), label: '运行'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: '日志'),
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
        Text('OneNET Studio 应用接入', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                DropdownButtonFormField<AuthMode>(
                  initialValue: _authMode,
                  items: const [
                    DropdownMenuItem(value: AuthMode.projectGroup, child: Text('项目分组鉴权')),
                    DropdownMenuItem(value: AuthMode.user, child: Text('用户鉴权')),
                  ],
                  onChanged: (value) => setState(() => _authMode = value ?? AuthMode.projectGroup),
                  decoration: const InputDecoration(labelText: '鉴权模式'),
                ),
                const SizedBox(height: 10),
                _TextField(controller: _projectId, label: 'Project ID'),
                if (_authMode == AuthMode.projectGroup) _TextField(controller: _groupId, label: 'Group ID'),
                if (_authMode == AuthMode.user) _TextField(controller: _userId, label: 'User ID'),
                _TextField(controller: _accessKey, label: 'Access Key', obscureText: true),
                _TextField(controller: _productId, label: 'Product ID'),
                _TextField(controller: _deviceName, label: 'Device Name'),
                Row(
                  children: [
                    Expanded(child: _TextField(controller: _refreshSeconds, label: '刷新秒数')),
                    const SizedBox(width: 10),
                    Expanded(child: _TextField(controller: _historyDays, label: '历史天数')),
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
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导出到 ${file.path}')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配置已保存')));
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
            content: Text('已从 Token.log 识别 Product ID 和 Device Name；DeviceKey 不会作为 APP AccessKey 使用'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Token.log 识别失败: $error')));
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
              onPressed: controller.addGraduateTemplates,
              icon: const Icon(Icons.extension),
              label: const Text('添加毕设模板'),
            ),
            OutlinedButton.icon(
              onPressed: controller.regenerateDashboard,
              icon: const Icon(Icons.auto_awesome_motion),
              label: const Text('重新生成面板'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (properties.isEmpty)
          const _EmptyPanel(
            icon: Icons.dataset_outlined,
            title: '还没有物模型',
            message: '导入 OneNET 导出的 TSL JSON，或添加内置毕设模板。',
          )
        else
          ...properties.map((property) => _PropertyTile(property: property)),
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
      final importResult = await controller.importThingModel(Uint8List.fromList(bytes));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '导入 ${importResult.properties.length} 个属性，跳过 ${importResult.skipped.length} 个',
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $error')));
      }
    }
  }
}

class _PropertyTile extends StatelessWidget {
  const _PropertyTile({required this.property});

  final ThingProperty property;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.sensors),
        title: Text(property.displayName),
        subtitle: Text('${property.identifier} · ${property.rawType} · ${property.accessMode.name}'),
        trailing: Wrap(
          spacing: 6,
          children: [
            if (property.unit.isNotEmpty) Chip(label: Text(property.unit)),
            if (property.writable) const Chip(label: Text('可控')),
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
    final state = controller.state;
    final propertyMap = {for (final property in state.properties) property.identifier: property};
    if (state.widgets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: _EmptyPanel(
          icon: Icons.dashboard_customize_outlined,
          title: '还没有面板控件',
          message: '导入物模型后会自动生成默认面板，也可以在物模型页手动重新生成。',
        ),
      );
    }
    final height = state.widgets.fold<double>(360, (max, item) => item.y + item.height + 32 > max ? item.y + item.height + 32 : max);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: height,
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
            for (final item in state.widgets)
              if (propertyMap[item.propertyIdentifier] != null)
                Positioned(
                  left: item.x,
                  top: item.y,
                  width: item.width,
                  height: item.height,
                  child: GestureDetector(
                    onPanUpdate: (details) async {
                      await controller.updateWidget(
                        item.copyWith(
                          x: (item.x + details.delta.dx).clamp(0, 700).toDouble(),
                          y: (item.y + details.delta.dy).clamp(0, 1600).toDouble(),
                        ),
                      );
                    },
                    child: DashboardTile(
                      config: item,
                      property: propertyMap[item.propertyIdentifier]!,
                      value: state.values[item.propertyIdentifier],
                      controller: controller,
                      editMode: true,
                      onDelete: () => controller.deleteWidget(item.id),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _RuntimeScreen extends StatelessWidget {
  const _RuntimeScreen({required this.controller});

  final LinkBoxController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final propertyMap = {for (final property in state.properties) property.identifier: property};
    final widgets = state.widgets.where((item) => propertyMap.containsKey(item.propertyIdentifier)).toList();
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
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 390,
          mainAxisExtent: 170,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: widgets.length,
        itemBuilder: (context, index) {
          final item = widgets[index];
          final property = propertyMap[item.propertyIdentifier]!;
          return DashboardTile(
            config: item,
            property: property,
            value: state.values[item.propertyIdentifier],
            controller: controller,
          );
        },
      ),
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
          subtitle: Text('${_formatDateTime(log.time)} · ${log.type}${log.detail.isEmpty ? '' : '\n${log.detail}'}'),
          isThreeLine: log.detail.isNotEmpty,
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: logs.length,
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
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
              Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
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
            for (final skipped in result.skipped) Text('跳过 ${skipped.identifier}: ${skipped.reason}'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('知道了')),
      ],
    );
  }
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
