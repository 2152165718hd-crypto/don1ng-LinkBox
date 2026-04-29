import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../runtime/linkbox_controller.dart';
import '../storage/models.dart';

class DashboardTile extends StatelessWidget {
  const DashboardTile({
    super.key,
    required this.config,
    required this.property,
    required this.value,
    required this.controller,
    this.editMode = false,
    this.onDelete,
  });

  final DashboardWidgetConfig config;
  final ThingProperty property;
  final RuntimeValue? value;
  final LinkBoxController controller;
  final bool editMode;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final child = switch (config.type) {
      DashboardWidgetType.switchControl => _SwitchControl(property: property, value: value, controller: controller),
      DashboardWidgetType.slider => _SliderControl(property: property, value: value, controller: controller),
      DashboardWidgetType.enumSelect => _EnumControl(property: property, value: value, controller: controller),
      DashboardWidgetType.trendChart => _TrendChart(property: property, controller: controller),
      DashboardWidgetType.textLabel => _ValueCard(property: property, value: value),
      DashboardWidgetType.valueCard => _ValueCard(property: property, value: value),
    };

    return Card(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
          if (editMode)
            Positioned(
              top: 4,
              right: 4,
              child: PopupMenuButton<String>(
                tooltip: '控件操作',
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (value) async {
                  if (value == 'delete') {
                    onDelete?.call();
                    return;
                  }
                  final scale = value == 'bigger' ? 1.12 : 0.9;
                  await controller.updateWidget(
                    config.copyWith(
                      width: (config.width * scale).clamp(120, 380).toDouble(),
                      height: (config.height * scale).clamp(92, 260).toDouble(),
                    ),
                  );
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'bigger', child: Text('放大')),
                  PopupMenuItem(value: 'smaller', child: Text('缩小')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({
    required this.property,
    required this.value,
  });

  final ThingProperty property;
  final RuntimeValue? value;

  @override
  Widget build(BuildContext context) {
    final display = value?.value?.toString() ?? '--';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_iconFor(property), size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                property.displayName,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            property.unit.isEmpty ? display : '$display ${property.unit}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value == null ? '暂无数据' : _formatTime(value!.time),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SwitchControl extends StatefulWidget {
  const _SwitchControl({
    required this.property,
    required this.value,
    required this.controller,
  });

  final ThingProperty property;
  final RuntimeValue? value;
  final LinkBoxController controller;

  @override
  State<_SwitchControl> createState() => _SwitchControlState();
}

class _SwitchControlState extends State<_SwitchControl> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final current = widget.value?.value == true || widget.value?.value?.toString() == 'true';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.property.displayName, style: Theme.of(context).textTheme.labelLarge),
        const Spacer(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(current ? '开启' : '关闭'),
          value: current,
          onChanged: _busy || !widget.controller.state.deviceOnline
              ? null
              : (value) async {
                  setState(() => _busy = true);
                  final error = await widget.controller.sendControl(widget.property, value);
                  setState(() => _busy = false);
                  if (error != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                  }
                },
        ),
      ],
    );
  }
}

class _SliderControl extends StatefulWidget {
  const _SliderControl({
    required this.property,
    required this.value,
    required this.controller,
  });

  final ThingProperty property;
  final RuntimeValue? value;
  final LinkBoxController controller;

  @override
  State<_SliderControl> createState() => _SliderControlState();
}

class _SliderControlState extends State<_SliderControl> {
  double? _draft;

  @override
  Widget build(BuildContext context) {
    final min = (widget.property.min ?? 0).toDouble();
    final max = (widget.property.max ?? 100).toDouble();
    final current = _draft ?? double.tryParse(widget.value?.value?.toString() ?? '') ?? min;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.property.displayName, style: Theme.of(context).textTheme.labelLarge),
        const Spacer(),
        Text('${current.toStringAsFixed(widget.property.type == ThingDataType.int32 ? 0 : 1)} ${widget.property.unit}'),
        Slider(
          value: current.clamp(min, max).toDouble(),
          min: min,
          max: max <= min ? min + 1 : max,
          divisions: widget.property.step == null
              ? null
              : ((max - min) / widget.property.step!).round().clamp(1, 1000).toInt(),
          onChanged: widget.controller.state.deviceOnline ? (value) => setState(() => _draft = value) : null,
          onChangeEnd: (value) async {
            final controlValue = widget.property.type == ThingDataType.int32 || widget.property.type == ThingDataType.int64
                ? value.round()
                : value;
            final error = await widget.controller.sendControl(widget.property, controlValue);
            if (error != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
            }
          },
        ),
      ],
    );
  }
}

class _EnumControl extends StatelessWidget {
  const _EnumControl({
    required this.property,
    required this.value,
    required this.controller,
  });

  final ThingProperty property;
  final RuntimeValue? value;
  final LinkBoxController controller;

  @override
  Widget build(BuildContext context) {
    final current = value?.value?.toString();
    final entries = property.enumValues.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(property.displayName, style: Theme.of(context).textTheme.labelLarge),
        const Spacer(),
        DropdownButtonFormField<String>(
          initialValue: entries.any((item) => item.key == current) ? current : null,
          items: entries
              .map((entry) => DropdownMenuItem(value: entry.key, child: Text('${entry.value} (${entry.key})')))
              .toList(),
          onChanged: controller.state.deviceOnline
              ? (next) async {
                  if (next == null) return;
                  final error = await controller.sendControl(property, next);
                  if (error != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                  }
                }
              : null,
          decoration: const InputDecoration(labelText: '枚举值'),
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.property,
    required this.controller,
  });

  final ThingProperty property;
  final LinkBoxController controller;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RuntimeValue>>(
      future: controller.loadHistory(property),
      builder: (context, snapshot) {
        final values = snapshot.data ?? const [];
        final spots = <FlSpot>[];
        for (var i = 0; i < values.length; i++) {
          final y = double.tryParse(values[i].value?.toString() ?? '');
          if (y != null) spots.add(FlSpot(i.toDouble(), y));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(property.displayName, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Expanded(
              child: spots.isEmpty
                  ? Center(child: Text(snapshot.connectionState == ConnectionState.waiting ? '加载中' : '暂无历史数据'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
                        titlesData: const FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34)),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: Theme.of(context).colorScheme.primary,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

IconData _iconFor(ThingProperty property) {
  final id = property.identifier.toLowerCase();
  if (id.contains('temp')) return Icons.thermostat;
  if (id.contains('hum')) return Icons.water_drop;
  if (id.contains('light') || id.contains('illum')) return Icons.wb_sunny;
  if (id.contains('smoke') || id.contains('gas')) return Icons.cloud;
  if (id.contains('relay') || id.contains('switch')) return Icons.power_settings_new;
  if (id.contains('motor')) return Icons.settings_input_component;
  return Icons.sensors;
}

String _formatTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}
