import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'core/app_theme.dart';
import 'core/formatters.dart';
import 'dashboard/dashboard_constants.dart';
import 'dashboard/dashboard_widgets.dart';
import 'dashboard/icon_library.dart';
import 'onenet/onenet_mqtt_service.dart';
import 'runtime/linkbox_controller.dart';
import 'runtime/property_history_screen.dart';
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
  final _deviceKey = TextEditingController();
  final _deviceToken = TextEditingController();
  final _refreshSeconds = TextEditingController();
  final _historyDays = TextEditingController();
  AuthMode _authMode = AuthMode.deviceToken;
  bool _mqttUseTls = false;
  String _fingerprint = '';
  bool _hasUserEdited = false;
  bool _syncingControllers = false;

  @override
  void initState() {
    super.initState();
    for (final controller in _textControllers) {
      controller.addListener(_markUserEdited);
    }
    widget.controller.addListener(_syncFromStateIfPristine);
    _syncControllers(widget.controller.state.config, markPristine: true);
  }

  @override
  void didUpdateWidget(covariant _ConfigScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_syncFromStateIfPristine);
    widget.controller.addListener(_syncFromStateIfPristine);
    _syncFromStateIfPristine();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromStateIfPristine);
    _projectId.dispose();
    _groupId.dispose();
    _userId.dispose();
    _accessKey.dispose();
    _productId.dispose();
    _deviceName.dispose();
    _deviceKey.dispose();
    _deviceToken.dispose();
    _refreshSeconds.dispose();
    _historyDays.dispose();
    super.dispose();
  }

  List<TextEditingController> get _textControllers => [
        _projectId,
        _groupId,
        _userId,
        _accessKey,
        _productId,
        _deviceName,
        _deviceKey,
        _deviceToken,
        _refreshSeconds,
        _historyDays,
      ];

  void _markUserEdited() {
    if (!_syncingControllers) {
      _hasUserEdited = true;
    }
  }

  void _syncFromStateIfPristine() {
    if (!mounted || _hasUserEdited) return;
    final nextFingerprint = _configFingerprint(widget.controller.state.config);
    if (_fingerprint == nextFingerprint) return;
    setState(() {
      _syncControllers(widget.controller.state.config, markPristine: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final config = state.config;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('设备 Token 快速接入', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConfigStatusCard(
                  config: config,
                  propertyCount: state.properties.length,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AuthMode>(
                  initialValue: _authMode,
                  items: const [
                    DropdownMenuItem(
                      value: AuthMode.deviceToken,
                      child: Text('简单设备 Token'),
                    ),
                    DropdownMenuItem(
                      value: AuthMode.projectGroup,
                      child: Text('高级项目分组鉴权'),
                    ),
                    DropdownMenuItem(
                      value: AuthMode.user,
                      child: Text('高级用户鉴权'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _hasUserEdited = true;
                    _authMode = value ?? AuthMode.deviceToken;
                  }),
                  decoration: const InputDecoration(labelText: '连接方式'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _importTokenLog,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('导入 Token.log'),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                        child: _TextField(
                            controller: _productId, label: 'Product ID')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _TextField(
                            controller: _deviceName, label: 'Device Name')),
                  ],
                ),
                if (_authMode == AuthMode.deviceToken) ...[
                  _TextField(
                    controller: _deviceKey,
                    label: 'Device Key / key',
                    obscureText: true,
                  ),
                  _TextField(
                    controller: _deviceToken,
                    label: 'Token / token',
                    obscureText: true,
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('启用 SSL/TLS 加密'),
                  value: _mqttUseTls,
                  onChanged: (value) => setState(() {
                    _hasUserEdited = true;
                    _mqttUseTls = value;
                  }),
                ),
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
                if (_authMode != AuthMode.deviceToken) ...[
                  const SizedBox(height: 4),
                  ExpansionTile(
                    key: ValueKey(_authMode),
                    initiallyExpanded: true,
                    tilePadding: EdgeInsets.zero,
                    title: const Text('高级应用接入'),
                    subtitle: const Text(
                        '需要 Project ID、Group ID/User ID 和 AccessKey'),
                    childrenPadding: EdgeInsets.zero,
                    children: [
                      _TextField(controller: _projectId, label: 'Project ID'),
                      if (_authMode == AuthMode.projectGroup)
                        _TextField(controller: _groupId, label: 'Group ID'),
                      if (_authMode == AuthMode.user)
                        _TextField(controller: _userId, label: 'User ID'),
                      _TextField(
                          controller: _accessKey,
                          label: 'Access Key',
                          obscureText: true),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
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
                      onPressed: _connect,
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
                    OutlinedButton.icon(
                      onPressed: _importBackup,
                      icon: const Icon(Icons.settings_backup_restore),
                      label: const Text('导入备份'),
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

  String _configFingerprint(ProjectConfig config) {
    return [
      config.projectId,
      config.groupId,
      config.userId,
      config.accessKey,
      config.productId,
      config.deviceName,
      config.deviceKey,
      config.deviceToken,
      config.deviceTokenMethod,
      config.deviceTokenVersion,
      config.deviceTokenExpiresAt?.millisecondsSinceEpoch,
      config.authMode.name,
      config.refreshSeconds,
      config.historyDays,
      config.mqttUseTls,
    ].join('|');
  }

  void _syncControllers(ProjectConfig config, {bool markPristine = false}) {
    final nextFingerprint = _configFingerprint(config);
    if (_fingerprint == nextFingerprint) {
      if (markPristine) _hasUserEdited = false;
      return;
    }
    _fingerprint = nextFingerprint;
    _syncingControllers = true;
    try {
      _projectId.text = config.projectId;
      _groupId.text = config.groupId;
      _userId.text = config.userId;
      _accessKey.text = config.accessKey;
      _productId.text = config.productId;
      _deviceName.text = config.deviceName;
      _deviceKey.text = config.deviceKey;
      _deviceToken.text = config.deviceToken;
      _authMode = config.authMode;
      _refreshSeconds.text = config.refreshSeconds.toString();
      _historyDays.text = config.historyDays.toString();
      _mqttUseTls = config.mqttUseTls;
    } finally {
      _syncingControllers = false;
    }
    if (markPristine) {
      _hasUserEdited = false;
    }
  }

  Future<void> _save({bool showSnackBar = true}) async {
    final current = widget.controller.state.config;
    final deviceToken = _deviceToken.text.trim();
    final tokenExpiresAt = deviceToken == current.deviceToken
        ? current.deviceTokenExpiresAt
        : null;
    final config = ProjectConfig(
      projectId: _projectId.text.trim(),
      groupId: _groupId.text.trim(),
      userId: _userId.text.trim(),
      accessKey: _accessKey.text.trim(),
      productId: _productId.text.trim(),
      deviceName: _deviceName.text.trim(),
      deviceKey: _deviceKey.text.trim(),
      deviceToken: deviceToken,
      deviceTokenMethod: current.deviceTokenMethod,
      deviceTokenVersion: current.deviceTokenVersion,
      deviceTokenExpiresAt: tokenExpiresAt,
      authMode: _authMode,
      refreshSeconds: int.tryParse(_refreshSeconds.text.trim()) ?? 15,
      historyDays: int.tryParse(_historyDays.text.trim()) ?? 7,
      mqttUseTls: _mqttUseTls,
    );
    await widget.controller.saveConfig(config);
    if (mounted) {
      setState(() => _syncControllers(config, markPristine: true));
      if (showSnackBar) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('配置已保存')));
      }
    }
  }

  Future<void> _importTokenLog() async {
    final result = await FilePicker.platform.pickFiles(
      // Android document providers can hide .log files behind custom filters.
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = await _readPickedFileBytes(file);
    if (bytes == null) {
      if (!mounted) return;
      _showSnackBar(context, '无法读取 ${file.name}');
      return;
    }
    try {
      final config = await widget.controller.importTokenLog(
        ConnectionImportFile(name: file.name, bytes: bytes),
      );
      if (!mounted) return;
      setState(() {
        _syncControllers(config, markPristine: true);
      });
      _showSnackBar(context, 'Token.log 已导入，可直接连接');
    } catch (error) {
      if (mounted) {
        _showSnackBar(context, 'Token.log 导入失败: $error');
      }
    }
  }

  Future<void> _connect() async {
    try {
      await _save(showSnackBar: false);
      final failure = await widget.controller.connectRealtime();
      if (!mounted || failure == null) return;
      await _showConnectionFailureDialog(context, failure);
    } catch (error) {
      if (!mounted) return;
      await _showConnectionFailureDialog(
        context,
        ConnectionFailureInfo(
          field: '本地配置',
          reason: '保存连接信息失败。',
          suggestion: '检查本机存储权限后重试。',
          detail: error.toString(),
        ),
      );
    }
  }

  Future<void> _importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = await _readPickedFileBytes(result.files.single);
    if (bytes == null) {
      if (!mounted) return;
      _showSnackBar(context, '无法读取备份文件内容');
      return;
    }
    try {
      await widget.controller.importBackup(bytes);
      if (mounted) {
        setState(() {
          _syncControllers(
            widget.controller.state.config,
            markPristine: true,
          );
        });
        _showSnackBar(context, '备份已导入');
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar(context, '备份导入失败: $error');
      }
    }
  }
}

class _ConfigStatusCard extends StatelessWidget {
  const _ConfigStatusCard({
    required this.config,
    required this.propertyCount,
  });

  final ProjectConfig config;
  final int propertyCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = config.isReady;
    final mode = config.usesDeviceToken ? '简单设备 Token' : '高级应用接入';
    final tokenExpiresAt = config.deviceTokenExpiresAt;
    final tokenText = config.deviceKey.trim().isNotEmpty
        ? 'Device Key 已填写，可自动生成'
        : config.deviceToken.trim().isEmpty
            ? '未填写'
            : tokenExpiresAt == null
                ? 'Token 已填写'
                : _formatDateTime(tokenExpiresAt);
    final mqttText = config.mqttUseTls ? 'SSL/TLS MQTT 8883' : '非加密 MQTT 1883';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.check_circle : Icons.info_outline,
                color: ready ? Colors.green : scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ready ? '连接信息已就绪' : '请导入 Token.log 或手动填写连接信息',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('模式：$mode'),
          Text(
              'Product ID：${config.productId.isEmpty ? '-' : config.productId}'),
          Text(
              'Device Name：${config.deviceName.isEmpty ? '-' : config.deviceName}'),
          Text('MQTT：$mqttText'),
          Text('Token：$tokenText'),
          Text('物模型属性：$propertyCount'),
        ],
      ),
    );
  }
}

class _ThingModelScreen extends StatelessWidget {
  const _ThingModelScreen({required this.controller});

  final LinkBoxController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final properties = state.properties;
    final hasThingModelData = properties.isNotEmpty ||
        state.pages.isNotEmpty ||
        state.widgets.isNotEmpty ||
        state.values.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
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
            OutlinedButton.icon(
              onPressed: hasThingModelData && !state.busy
                  ? () => _confirmClearThingModel(context)
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除物模型'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (properties.isEmpty)
          const _EmptyPanel(
            icon: Icons.dataset_outlined,
            title: '还没有物模型',
            message:
                '请导入 OneNET Studio 导出的 TSL JSON。导入后，每个属性会自动生成可编辑的实时 UI 卡片；历史曲线请在运行页点击数据查看。',
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
    final bytes = await _readPickedFileBytes(file);
    if (bytes == null) {
      if (!context.mounted) return;
      _showSnackBar(context, '无法读取物模型文件内容');
      return;
    }
    try {
      final importResult = await controller.importThingModel(bytes);
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

  Future<void> _confirmClearThingModel(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除当前物模型？'),
          content: const Text(
            '将删除已导入的物模型、面板配置和本地历史数据，并断开当前实时连接。云平台配置和日志会保留。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (!context.mounted || confirmed != true) return;
    try {
      await controller.clearThingModel();
      if (!context.mounted) return;
      _showSnackBar(context, '物模型已删除');
    } catch (error) {
      if (!context.mounted) return;
      _showSnackBar(context, '删除失败: $error');
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
                  label: const Text('配置实时 UI'),
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
          message: '导入物模型后会自动生成可编辑的实时 UI 卡片，也可以在物模型页补齐默认面板。',
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
          message: '请先导入物模型并生成实时面板，然后点击数据卡片查看历史曲线。',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refreshLatest,
      child: _DashboardCanvas(
        controller: controller,
        editMode: false,
        alwaysScrollable: true,
        onHistoryTap: (property) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PropertyHistoryScreen(
                controller: controller,
                property: property,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardCanvas extends StatelessWidget {
  const _DashboardCanvas({
    required this.controller,
    required this.editMode,
    this.alwaysScrollable = false,
    this.onHistoryTap,
  });

  final LinkBoxController controller;
  final bool editMode;
  final bool alwaysScrollable;
  final ValueChanged<ThingProperty>? onHistoryTap;

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
        var canvasWidth =
            constraints.maxWidth - (DashboardLayoutConstants.canvasPadding * 2);
        var canvasHeight = DashboardLayoutConstants.minCanvasHeight;
        for (final item in widgets) {
          final right = item.x +
              item.width +
              DashboardLayoutConstants.canvasBorderPadding;
          final bottom = item.y +
              item.height +
              DashboardLayoutConstants.canvasBorderPadding;
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
                        onHistoryTap: onHistoryTap,
                        maxX: (canvasWidth - item.width)
                            .clamp(0.0, double.infinity)
                            .toDouble(),
                        maxY: (canvasHeight - item.height)
                            .clamp(0.0, double.infinity)
                            .toDouble(),
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
    this.onHistoryTap,
    required this.maxX,
    required this.maxY,
  });

  final LinkBoxController controller;
  final DashboardWidgetConfig config;
  final ThingProperty property;
  final RuntimeValue? value;
  final bool editMode;
  final ValueChanged<ThingProperty>? onHistoryTap;
  final double maxX;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    final tile = DashboardTile(
      config: config,
      property: property,
      value: value,
      controller: controller,
      editMode: editMode,
      onHistoryTap: onHistoryTap == null ? null : () => onHistoryTap!(property),
      onEdit: () =>
          _openWidgetStyleEditor(context, controller, property, config),
      onDelete: () => controller.deleteWidget(config.id),
    );
    if (!editMode) return tile;
    return GestureDetector(
      onPanUpdate: (details) async {
        await controller.updateWidget(
          config.copyWith(
            x: (config.x + details.delta.dx).clamp(0.0, maxX).toDouble(),
            y: (config.y + details.delta.dy).clamp(0.0, maxY).toDouble(),
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
    _syncIconValueForKind(_iconKind);
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

  void _syncIconValueForKind(
    DashboardIconKind kind, {
    DashboardIconKind? previousKind,
  }) {
    switch (kind) {
      case DashboardIconKind.none:
        _iconValue = '';
        break;
      case DashboardIconKind.material:
        if (!LinkBoxIconLibrary.materialIcons
            .any((item) => item.key == _iconValue)) {
          _iconValue = LinkBoxIconLibrary.materialIcons.first.key;
        }
        break;
      case DashboardIconKind.builtinSvg:
        if (!LinkBoxIconLibrary.builtinSvgIcons
            .any((item) => item.key == _iconValue)) {
          _iconValue = LinkBoxIconLibrary.builtinSvgIcons.first.key;
        }
        break;
      case DashboardIconKind.builtinPng:
        if (!LinkBoxIconLibrary.builtinPngIcons
            .any((item) => item.key == _iconValue)) {
          _iconValue = LinkBoxIconLibrary.builtinPngIcons.last.key;
        }
        break;
      case DashboardIconKind.uploadedPng:
        if (previousKind != null &&
            previousKind != DashboardIconKind.uploadedPng) {
          _iconValue = '';
        }
        break;
    }
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
                    final previousKind = _iconKind;
                    _iconKind = value;
                    _syncIconValueForKind(_iconKind,
                        previousKind: previousKind);
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
    final bytes = await _readPickedFileBytes(file);
    if (bytes == null) return;
    setState(() => _savingIcon = true);
    final savedPath = await widget.controller.saveUploadedIcon(
      bytes: bytes,
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
        .clamp(
          DashboardLayoutConstants.minCardWidth,
          DashboardLayoutConstants.maxCardWidth,
        )
        .toDouble();
    final height =
        (double.tryParse(_height.text.trim()) ?? widget.initial.height)
            .clamp(
              DashboardLayoutConstants.minCardHeight,
              DashboardLayoutConstants.maxCardHeight,
            )
            .toDouble();
    final decimalDigits = (int.tryParse(_decimalDigits.text.trim()) ??
            widget.initial.decimalDigits)
        .clamp(0, DashboardLayoutConstants.maxDecimalDigits)
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
        return _IconGridSelector<MaterialIconOption>(
          title: 'Material 矢量图标',
          value: current,
          options: LinkBoxIconLibrary.materialIcons,
          optionKey: (item) => item.key,
          optionLabel: (item) => item.label,
          optionCategory: (item) => item.category,
          optionKeywords: (item) => item.keywords,
          iconBuilder: (context, item, color) =>
              Icon(item.icon, size: 26, color: color),
          onChanged: onChanged,
        );
      case DashboardIconKind.builtinSvg:
        final current =
            LinkBoxIconLibrary.builtinSvgIcons.any((item) => item.key == value)
                ? value
                : LinkBoxIconLibrary.builtinSvgIcons.first.key;
        return _IconGridSelector<BuiltinSvgIcon>(
          title: '内置 SVG 图库',
          value: current,
          options: LinkBoxIconLibrary.builtinSvgIcons,
          optionKey: (item) => item.key,
          optionLabel: (item) => item.label,
          optionCategory: (item) => item.category,
          optionKeywords: (item) => item.keywords,
          iconBuilder: (context, item, color) => SvgPicture.asset(
            item.asset,
            width: 26,
            height: 26,
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          onChanged: onChanged,
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

class _IconGridSelector<T> extends StatefulWidget {
  const _IconGridSelector({
    required this.title,
    required this.value,
    required this.options,
    required this.optionKey,
    required this.optionLabel,
    required this.optionCategory,
    required this.optionKeywords,
    required this.iconBuilder,
    required this.onChanged,
  });

  final String title;
  final String value;
  final List<T> options;
  final String Function(T item) optionKey;
  final String Function(T item) optionLabel;
  final String Function(T item) optionCategory;
  final List<String> Function(T item) optionKeywords;
  final Widget Function(BuildContext context, T item, Color color) iconBuilder;
  final ValueChanged<String> onChanged;

  @override
  State<_IconGridSelector<T>> createState() => _IconGridSelectorState<T>();
}

class _IconGridSelectorState<T> extends State<_IconGridSelector<T>> {
  static const _allCategories = '全部';

  String _query = '';
  String _category = _allCategories;

  @override
  Widget build(BuildContext context) {
    final categories = [
      _allCategories,
      ...{for (final item in widget.options) widget.optionCategory(item)},
    ];
    final selectedCategory =
        categories.contains(_category) ? _category : _allCategories;
    final filtered = widget.options.where((item) {
      final category = widget.optionCategory(item);
      if (selectedCategory != _allCategories && category != selectedCategory) {
        return false;
      }
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) return true;
      final searchable = [
        widget.optionKey(item),
        widget.optionLabel(item),
        category,
        ...widget.optionKeywords(item),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search),
            labelText: '搜索图标',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ChoiceChip(
                selected: selectedCategory == category,
                label: Text(category),
                onSelected: (_) => setState(() => _category = category),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 284,
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    '未找到匹配图标',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final rawCount = (constraints.maxWidth / 84).floor();
                    final crossAxisCount = rawCount.clamp(3, 6).toInt();
                    return GridView.builder(
                      itemCount: filtered.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisExtent: 76,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final key = widget.optionKey(item);
                        final selected = key == widget.value;
                        return _IconGridTile<T>(
                          item: item,
                          label: widget.optionLabel(item),
                          selected: selected,
                          iconBuilder: widget.iconBuilder,
                          onTap: () => widget.onChanged(key),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _IconGridTile<T> extends StatelessWidget {
  const _IconGridTile({
    required this.item,
    required this.label,
    required this.selected,
    required this.iconBuilder,
    required this.onTap,
  });

  final T item;
  final String label;
  final bool selected;
  final Widget Function(BuildContext context, T item, Color color) iconBuilder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground =
        selected ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final background =
        selected ? colorScheme.primaryContainer : colorScheme.surface;
    final borderColor =
        selected ? colorScheme.primary : colorScheme.outlineVariant;

    return Tooltip(
      message: label,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 28,
                  child: Center(child: iconBuilder(context, item, foreground)),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: foreground,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
            const Text(
                '2. 在设备页导入 Token.log，或手动填写 Product ID、Device Name、Device Key/Token。'),
            const Text(
                '3. 物模型 JSON 在物模型页单独导入，导入后会生成可编辑的实时 UI 卡片；历史曲线在运行页点击数据查看。'),
            const Text('4. 需要云端历史查询时，再展开高级应用接入填写应用鉴权。'),
            const SizedBox(height: 8),
            Text(
              '简单模式使用设备 Token MQTT，可能占用同一设备在线身份。',
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

Future<Uint8List?> _readPickedFileBytes(PlatformFile file) async {
  if (file.bytes != null) return file.bytes;
  final path = file.path;
  if (path == null) return null;
  return File(path).readAsBytes();
}

void _showSnackBar(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _showConnectionFailureDialog(
  BuildContext context,
  ConnectionFailureInfo failure,
) {
  final detail = failure.detail.trim();
  return showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('连接失败'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('出错位置：${failure.field}'),
            const SizedBox(height: 8),
            Text('原因：${failure.reason}'),
            const SizedBox(height: 8),
            Text('处理：${failure.suggestion}'),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '详情：$detail',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
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
    DashboardIconKind.builtinSvg => '内置 SVG 图库',
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
  return formatDateTime(time);
}
