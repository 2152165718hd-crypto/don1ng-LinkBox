import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/formatters.dart';
import '../runtime/linkbox_controller.dart';
import '../storage/models.dart';
import 'icon_library.dart';

class DashboardTile extends StatelessWidget {
  const DashboardTile({
    super.key,
    required this.config,
    required this.property,
    required this.value,
    required this.controller,
    this.editMode = false,
    this.onEdit,
    this.onDelete,
    this.onHistoryTap,
  });

  final DashboardWidgetConfig config;
  final ThingProperty property;
  final RuntimeValue? value;
  final LinkBoxController controller;
  final bool editMode;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final foreground = Color(config.textColor);
    final child = switch (config.displayMode) {
      DashboardDisplayMode.value => _ValueCard(
          config: config,
          property: property,
          value: value,
          onHistoryTap: onHistoryTap,
        ),
      DashboardDisplayMode.progress => _ProgressCard(
          config: config,
          property: property,
          value: value,
          onHistoryTap: onHistoryTap,
        ),
      DashboardDisplayMode.slider => _SliderControl(
          config: config,
          property: property,
          value: value,
          controller: controller,
          onHistoryTap: onHistoryTap,
        ),
      DashboardDisplayMode.gauge => _GaugeCard(
          config: config,
          property: property,
          value: value,
          onHistoryTap: onHistoryTap,
        ),
      DashboardDisplayMode.switcher => _SwitchControl(
          config: config,
          property: property,
          value: value,
          controller: controller,
          onHistoryTap: onHistoryTap,
        ),
      DashboardDisplayMode.button => _ButtonControl(
          config: config,
          property: property,
          value: value,
          controller: controller,
          onHistoryTap: onHistoryTap,
        ),
      DashboardDisplayMode.enumSelect => _EnumControl(
          config: config,
          property: property,
          value: value,
          controller: controller,
          onHistoryTap: onHistoryTap,
        ),
      DashboardDisplayMode.status => _StatusCard(
          config: config,
          property: property,
          value: value,
          onHistoryTap: onHistoryTap,
        ),
      DashboardDisplayMode.text => _TextCard(
          config: config,
          property: property,
          value: value,
          onHistoryTap: onHistoryTap,
        ),
      DashboardDisplayMode.trendChart => _ValueCard(
          config: config,
          property: property,
          value: value,
          onHistoryTap: onHistoryTap,
        ),
    };

    final canOpenHistory = onHistoryTap != null && !editMode;
    final isControlWidget = switch (config.displayMode) {
      DashboardDisplayMode.slider ||
      DashboardDisplayMode.switcher ||
      DashboardDisplayMode.button ||
      DashboardDisplayMode.enumSelect =>
        true,
      _ => false,
    };
    final tileBody = canOpenHistory && !isControlWidget
        ? InkWell(
            onTap: onHistoryTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          );

    return Card(
      color: Color(config.backgroundColor),
      clipBehavior: Clip.antiAlias,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: IconTheme.merge(
          data: IconThemeData(color: foreground),
          child: Stack(
            children: [
              tileBody,
              if (editMode)
                Positioned(
                  top: 2,
                  right: 2,
                  child: PopupMenuButton<String>(
                    tooltip: '控件操作',
                    icon: Icon(Icons.more_vert, size: 18, color: foreground),
                    onSelected: (selected) {
                      if (selected == 'edit') onEdit?.call();
                      if (selected == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑样式和尺寸')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileHeader extends StatelessWidget {
  const _TileHeader({
    required this.config,
    required this.property,
    this.onHistoryTap,
  });

  final DashboardWidgetConfig config;
  final ThingProperty property;
  final VoidCallback? onHistoryTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ConfiguredIcon(config: config, property: property, size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            config.title.trim().isEmpty ? property.displayName : config.title,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Color(config.textColor),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (onHistoryTap != null)
          IconButton(
            tooltip: '查看历史',
            onPressed: onHistoryTap,
            icon: const Icon(Icons.show_chart),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          ),
      ],
    );
  }
}

class _ConfiguredIcon extends StatelessWidget {
  const _ConfiguredIcon({
    required this.config,
    required this.property,
    this.size = 28,
  });

  final DashboardWidgetConfig config;
  final ThingProperty property;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (config.iconKind) {
      case DashboardIconKind.none:
        return SizedBox(width: size, height: size);
      case DashboardIconKind.material:
        final option = LinkBoxIconLibrary.materialByKey(config.iconValue);
        return Icon(option.icon,
            size: size, color: Theme.of(context).colorScheme.primary);
      case DashboardIconKind.builtinSvg:
        final icon = LinkBoxIconLibrary.builtinSvgByKey(config.iconValue);
        return SvgPicture.asset(
          icon.asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(
            Theme.of(context).colorScheme.primary,
            BlendMode.srcIn,
          ),
        );
      case DashboardIconKind.builtinPng:
        final icon = LinkBoxIconLibrary.builtinByKey(config.iconValue);
        return Image.asset(icon.asset,
            width: size, height: size, filterQuality: FilterQuality.high);
      case DashboardIconKind.uploadedPng:
        final file = File(config.iconValue);
        if (config.iconValue.isNotEmpty && file.existsSync()) {
          return Image.file(file,
              width: size, height: size, filterQuality: FilterQuality.high);
        }
        return Icon(Icons.broken_image_outlined,
            size: size, color: Theme.of(context).colorScheme.error);
    }
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({
    required this.config,
    required this.property,
    required this.value,
    this.onHistoryTap,
  });

  final DashboardWidgetConfig config;
  final ThingProperty property;
  final RuntimeValue? value;
  final VoidCallback? onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final display = _formatDisplayValue(config, property, value?.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TileHeader(
          config: config,
          property: property,
          onHistoryTap: onHistoryTap,
        ),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            display,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Color(config.textColor),
                ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value == null ? '暂无数据' : _formatTime(value!.time),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: _subtleTextColor(config)),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.config,
    required this.property,
    required this.value,
    this.onHistoryTap,
  });

  final DashboardWidgetConfig config;
  final ThingProperty property;
  final RuntimeValue? value;
  final VoidCallback? onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final display = _formatDisplayValue(config, property, value?.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TileHeader(
          config: config,
          property: property,
          onHistoryTap: onHistoryTap,
        ),
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            display,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Color(config.textColor),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({
    required this.config,
    required this.property,
    required this.value,
    this.onHistoryTap,
  });

  final DashboardWidgetConfig config;
  final ThingProperty property;
  final RuntimeValue? value;
  final VoidCallback? onHistoryTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TileHeader(
          config: config,
          property: property,
          onHistoryTap: onHistoryTap,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Text(
            value?.value?.toString() ?? '暂无数据',
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Color(config.textColor)),
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.config,
    required this.property,
    required this.value,
    this.onHistoryTap,
  });

  final DashboardWidgetConfig config;
  final ThingProperty property;
  final RuntimeValue? value;
  final VoidCallback? onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final progress = _normalizedProgress(property, value?.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TileHeader(
          config: config,
          property: property,
          onHistoryTap: onHistoryTap,
        ),
        const Spacer(),
        Text(
          _formatDisplayValue(config, property, value?.value),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Color(config.textColor),
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: progress,
          minHeight: 10,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }
}

class _GaugeCard extends StatelessWidget {
  const _GaugeCard({
    required this.config,
    required this.property,
    required this.value,
    this.onHistoryTap,
  });

  final DashboardWidgetConfig config;
  final ThingProperty property;
  final RuntimeValue? value;
  final VoidCallback? onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final progress = _normalizedProgress(property, value?.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TileHeader(
          config: config,
          property: property,
          onHistoryTap: onHistoryTap,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: CircularProgressIndicator(
                      value: progress, strokeWidth: 9),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatDisplayValue(config, property, value?.value),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Color(config.textColor),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchControl extends StatefulWidget {
  const _SwitchControl({
    required this.config,
    required this.property,
    required this.value,
    required this.controller,
    this.onHistoryTap,
  });

  final DashboardWidgetConfig config;
  final ThingProperty property;
  final RuntimeValue? value;
  final LinkBoxController controller;
  final VoidCallback? onHistoryTap;

  @override
  State<_SwitchControl> createState() => _SwitchControlState();
}

class _SwitchControlState extends State<_SwitchControl> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final current = _asBool(widget.value?.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TileHeader(
          config: widget.config,
          property: widget.property,
          onHistoryTap: widget.onHistoryTap,
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: Text(
                current ? '开启' : '关闭',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Color(widget.config.textColor),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Switch(
              value: current,
              onChanged: _busy || !widget.controller.state.deviceOnline
                  ? null
                  : (next) async {
                      setState(() => _busy = true);
                      final error = await widget.controller
                          .sendControl(widget.property, next);
                      if (mounted) setState(() => _busy = false);
                      if (error != null && context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(error)));
                      }
                    },
            ),
          ],
        ),
      ],
    );
  }
}

class _ButtonControl extends StatefulWidget {
  const _ButtonControl({
    required this.config,
    required this.property,
    required this.value,
    required this.controller,
    this.onHistoryTap,
  });

  final DashboardWidgetConfig config;
  final ThingProperty property;
  final RuntimeValue? value;
  final LinkBoxController controller;
  final VoidCallback? onHistoryTap;

  @override
  State<_ButtonControl> createState() => _ButtonControlState();
}

class _ButtonControlState extends State<_ButtonControl> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final current = _asBool(widget.value?.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TileHeader(
          config: widget.config,
          property: widget.property,
          onHistoryTap: widget.onHistoryTap,
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy || !widget.controller.state.deviceOnline
                ? null
                : () async {
                    setState(() => _busy = true);
                    final error = await widget.controller
                        .sendControl(widget.property, !current);
                    if (mounted) setState(() => _busy = false);
                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(error)));
                    }
                  },
            child: Text(current ? '关闭' : '开启'),
          ),
        ),
      ],
    );
  }
}

class _SliderControl extends StatefulWidget {
  const _SliderControl({
    required this.config,
    required this.property,
    required this.value,
    required this.controller,
    this.onHistoryTap,
  });

  final DashboardWidgetConfig config;
  final ThingProperty property;
  final RuntimeValue? value;
  final LinkBoxController controller;
  final VoidCallback? onHistoryTap;

  @override
  State<_SliderControl> createState() => _SliderControlState();
}

class _SliderControlState extends State<_SliderControl> {
  double? _draft;

  @override
  Widget build(BuildContext context) {
    final min = (widget.property.min ?? 0).toDouble();
    final rawMax = (widget.property.max ?? 100).toDouble();
    final max = rawMax <= min ? min + 1 : rawMax;
    final current =
        _draft ?? double.tryParse(widget.value?.value?.toString() ?? '') ?? min;
    final step = widget.property.step?.toDouble();
    final divisions = step == null || step <= 0
        ? null
        : ((max - min) / step).round().clamp(1, 1000).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TileHeader(
          config: widget.config,
          property: widget.property,
          onHistoryTap: widget.onHistoryTap,
        ),
        const Spacer(),
        Text(
          _formatDisplayValue(widget.config, widget.property, current),
          style: TextStyle(
              color: Color(widget.config.textColor),
              fontWeight: FontWeight.w700),
        ),
        Slider(
          value: current.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: widget.controller.state.deviceOnline
              ? (next) => setState(() => _draft = next)
              : null,
          onChangeEnd: widget.controller.state.deviceOnline
              ? (next) async {
                  final controlValue =
                      widget.property.type == ThingDataType.int32 ||
                              widget.property.type == ThingDataType.int64
                          ? next.round()
                          : next;
                  final error = await widget.controller
                      .sendControl(widget.property, controlValue);
                  if (mounted) setState(() => _draft = null);
                  if (error != null && context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error)));
                  }
                }
              : null,
        ),
      ],
    );
  }
}

class _EnumControl extends StatelessWidget {
  const _EnumControl({
    required this.config,
    required this.property,
    required this.value,
    required this.controller,
    this.onHistoryTap,
  });

  final DashboardWidgetConfig config;
  final ThingProperty property;
  final RuntimeValue? value;
  final LinkBoxController controller;
  final VoidCallback? onHistoryTap;

  @override
  Widget build(BuildContext context) {
    final current = value?.value?.toString();
    final entries = property.enumValues.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TileHeader(
          config: config,
          property: property,
          onHistoryTap: onHistoryTap,
        ),
        const Spacer(),
        if (entries.isEmpty)
          Text(
            current ?? '暂无枚举值',
            style: TextStyle(
                color: Color(config.textColor), fontWeight: FontWeight.w700),
          )
        else
          DropdownButtonFormField<String>(
            initialValue:
                entries.any((item) => item.key == current) ? current : null,
            isExpanded: true,
            items: entries
                .map((entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text('${entry.value} (${entry.key})')))
                .toList(),
            onChanged: controller.state.deviceOnline
                ? (next) async {
                    if (next == null) return;
                    final error = await controller.sendControl(property, next);
                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(error)));
                    }
                  }
                : null,
            decoration: const InputDecoration(labelText: '枚举值'),
          ),
      ],
    );
  }
}

Color _subtleTextColor(DashboardWidgetConfig config) {
  return Color(config.textColor).withValues(alpha: 0.72);
}

double? _numericValue(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}

double _normalizedProgress(ThingProperty property, Object? raw) {
  final value = _numericValue(raw);
  if (value == null) return 0;
  final min = (property.min ?? 0).toDouble();
  final max = (property.max ?? 100).toDouble();
  if (max <= min) return 0;
  return ((value - min) / (max - min)).clamp(0, 1).toDouble();
}

bool _asBool(Object? raw) {
  if (raw is bool) return raw;
  final text = raw?.toString().trim().toLowerCase();
  return text == 'true' ||
      text == '1' ||
      text == 'on' ||
      text == 'open' ||
      text == '开' ||
      text == '开启';
}

String _formatDisplayValue(
    DashboardWidgetConfig config, ThingProperty property, Object? raw) {
  if (property.type == ThingDataType.boolType) {
    return _asBool(raw) ? '开启' : '关闭';
  }
  if (property.type == ThingDataType.enumType) {
    final key = raw?.toString() ?? '--';
    final label = property.enumValues[key];
    return label == null ? key : '$label ($key)';
  }
  final numeric = _numericValue(raw);
  final valueText = numeric == null
      ? raw?.toString() ?? '--'
      : numeric.toStringAsFixed(
          property.type == ThingDataType.int32 ||
                  property.type == ThingDataType.int64
              ? 0
              : config.decimalDigits,
        );
  if (config.showUnit && property.unit.isNotEmpty) {
    return '$valueText ${property.unit}';
  }
  return valueText;
}

String _formatTime(DateTime time) {
  return formatClockTime(time);
}
