import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../storage/models.dart';
import 'linkbox_controller.dart';

class PropertyHistoryScreen extends StatefulWidget {
  const PropertyHistoryScreen({
    super.key,
    required this.controller,
    required this.property,
  });

  final LinkBoxController controller;
  final ThingProperty property;

  @override
  State<PropertyHistoryScreen> createState() => _PropertyHistoryScreenState();
}

class _PropertyHistoryScreenState extends State<PropertyHistoryScreen> {
  late Future<List<RuntimeValue>> _historyFuture;
  late int _historyDays;

  @override
  void initState() {
    super.initState();
    _historyDays = widget.controller.state.config.historyDays;
    _historyFuture = widget.controller.loadHistory(widget.property);
  }

  @override
  void didUpdateWidget(covariant PropertyHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextHistoryDays = widget.controller.state.config.historyDays;
    final shouldReload = oldWidget.controller != widget.controller ||
        oldWidget.property.identifier != widget.property.identifier ||
        _historyDays != nextHistoryDays;
    if (shouldReload) {
      _historyDays = nextHistoryDays;
      _historyFuture = widget.controller.loadHistory(widget.property);
    }
  }

  Future<void> _reloadHistory() async {
    final nextHistoryDays = widget.controller.state.config.historyDays;
    final future = widget.controller.loadHistory(widget.property);
    setState(() {
      _historyDays = nextHistoryDays;
      _historyFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final latestFromState = state.values[widget.property.identifier];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.property.displayName}历史'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _reloadHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reloadHistory,
        child: FutureBuilder<List<RuntimeValue>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            final values = snapshot.data ?? const <RuntimeValue>[];
            final loading =
                snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;
            final latest = values.isNotEmpty ? values.last : latestFromState;
            final latestValue = latest?.value;
            final latestTime = latest?.time;
            final children = <Widget>[
              _HistoryOverview(
                property: widget.property,
                historyDays: _historyDays,
                count: values.length,
                latestValue: latestValue,
                latestTime: latestTime,
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  snapshot.hasData)
                const LinearProgressIndicator(minHeight: 2),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  snapshot.hasData)
                const SizedBox(height: 16),
              if (loading)
                const _LoadingPanel()
              else if (snapshot.hasError)
                _MessagePanel(
                  icon: Icons.error_outline,
                  title: '历史数据加载失败',
                  message: snapshot.error.toString(),
                )
              else if (values.isEmpty)
                _MessagePanel(
                  icon: Icons.query_stats_outlined,
                  title: '暂无历史数据',
                  message: '当前属性在最近 $_historyDays 天内没有可展示的历史记录。',
                )
              else if (_historyMode(widget.property) == _HistoryMode.list)
                _HistoryList(
                    values: values.reversed.toList(), property: widget.property)
              else
                _HistoryChartPanel(property: widget.property, values: values),
            ];

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: children,
            );
          },
        ),
      ),
    );
  }
}

enum _HistoryMode { numeric, step, list }

class _HistoryOverview extends StatelessWidget {
  const _HistoryOverview({
    required this.property,
    required this.historyDays,
    required this.count,
    required this.latestValue,
    required this.latestTime,
  });

  final ThingProperty property;
  final int historyDays;
  final int count;
  final Object? latestValue;
  final DateTime? latestTime;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  property.displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (property.unit.isNotEmpty) _MetaChip(label: property.unit),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatHistoryValue(property, latestValue),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            latestTime == null
                ? '暂无最新数据'
                : '最近更新 ${formatDateTime(latestTime!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(label: property.identifier),
              _MetaChip(label: _typeLabel(property.type)),
              _MetaChip(label: _accessModeLabel(property.accessMode)),
              _MetaChip(label: '近 $historyDays 天'),
              _MetaChip(label: '$count 条记录'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryChartPanel extends StatelessWidget {
  const _HistoryChartPanel({
    required this.property,
    required this.values,
  });

  final ThingProperty property;
  final List<RuntimeValue> values;

  @override
  Widget build(BuildContext context) {
    final series = _buildSeries(property, values);
    if (series == null) {
      return _MessagePanel(
        icon: Icons.query_stats_outlined,
        title: '暂无可绘制数据',
        message: '当前属性的数据无法转换为曲线。请检查历史记录内容。',
      );
    }

    final lineData = LineChartBarData(
      spots: series.spots,
      isCurved: series.mode == _HistoryMode.numeric,
      isStepLineChart: series.mode == _HistoryMode.step,
      lineChartStepData: const LineChartStepData(
          stepDirection: LineChartStepData.stepDirectionMiddle),
      color: Theme.of(context).colorScheme.primary,
      barWidth: 2,
      dotData: const FlDotData(show: false),
    );

    final maxX =
        series.spots.length <= 1 ? 1.0 : (series.spots.length - 1).toDouble();
    final minY = series.mode == _HistoryMode.step ? -0.5 : series.minY;
    final maxY = series.mode == _HistoryMode.step
        ? (series.labels.length <= 1 ? 1.0 : series.labels.length - 0.5)
        : series.maxY;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            series.mode == _HistoryMode.step ? '阶梯历史曲线' : '历史曲线',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: series.mode == _HistoryMode.step,
                      reservedSize: 46,
                      getTitlesWidget: (value, meta) {
                        if (series.mode != _HistoryMode.step) {
                          return const SizedBox.shrink();
                        }
                        final index = value.round();
                        if (index < 0 || index >= series.labels.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            series.labels[index],
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= series.spots.length) {
                          return const SizedBox.shrink();
                        }
                        if (series.spots.length > 4 &&
                            index != 0 &&
                            index != series.spots.length - 1 &&
                            index != series.spots.length ~/ 2) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            formatClockTime(series.times[index]),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [lineData],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.values,
    required this.property,
  });

  final List<RuntimeValue> values;
  final ThingProperty property;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '历史记录',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < values.length; i++) ...[
          _HistoryEntryTile(
            value: values[i],
            property: property,
          ),
          if (i != values.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _HistoryEntryTile extends StatelessWidget {
  const _HistoryEntryTile({
    required this.value,
    required this.property,
  });

  final RuntimeValue value;
  final ThingProperty property;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatHistoryValue(property, value.value),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            formatDateTime(value.time),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _HistorySeries {
  const _HistorySeries({
    required this.mode,
    required this.points,
    required this.labels,
    required this.minY,
    required this.maxY,
  });

  final _HistoryMode mode;
  final List<_HistoryPoint> points;
  final List<String> labels;
  final double minY;
  final double maxY;

  List<FlSpot> get spots => [
        for (var i = 0; i < points.length; i++)
          FlSpot(i.toDouble(), points[i].value)
      ];

  List<DateTime> get times => [for (final point in points) point.time];
}

class _HistoryPoint {
  const _HistoryPoint({
    required this.time,
    required this.value,
  });

  final DateTime time;
  final double value;
}

_HistorySeries? _buildSeries(
    ThingProperty property, List<RuntimeValue> values) {
  if (property.isNumeric) {
    final points = <_HistoryPoint>[];
    for (final value in values) {
      final numeric = _numericValue(value.value);
      if (numeric == null) continue;
      points.add(_HistoryPoint(time: value.time, value: numeric));
    }
    if (points.isEmpty) return null;
    var minY = points.first.value;
    var maxY = points.first.value;
    for (final point in points.skip(1)) {
      if (point.value < minY) minY = point.value;
      if (point.value > maxY) maxY = point.value;
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    } else {
      final padding = (maxY - minY) * 0.15;
      minY -= padding;
      maxY += padding;
    }
    return _HistorySeries(
      mode: _HistoryMode.numeric,
      points: points,
      labels: const [],
      minY: minY,
      maxY: maxY,
    );
  }

  if (property.type == ThingDataType.boolType ||
      property.type == ThingDataType.enumType) {
    final labels = property.type == ThingDataType.boolType
        ? <String>['关闭', '开启']
        : property.enumValues.entries
            .map((entry) => entry.value.isEmpty ? entry.key : entry.value)
            .toList();
    final indexByKey = <String, int>{
      if (property.type == ThingDataType.boolType) 'false': 0,
      if (property.type == ThingDataType.boolType) 'true': 1,
      for (var i = 0; i < property.enumValues.entries.length; i++)
        property.enumValues.entries.elementAt(i).key: i,
    };
    final points = <_HistoryPoint>[];
    for (final value in values) {
      final rawKey = property.type == ThingDataType.boolType
          ? _asBool(value.value)
              ? 'true'
              : 'false'
          : value.value?.toString() ?? '';
      final label = property.type == ThingDataType.boolType
          ? (_asBool(value.value) ? labels[1] : labels[0])
          : property.enumValues[rawKey] ?? (rawKey.isEmpty ? '--' : rawKey);
      final index = indexByKey.putIfAbsent(rawKey, () {
        labels.add(label);
        return labels.length - 1;
      });
      points.add(_HistoryPoint(time: value.time, value: index.toDouble()));
    }
    if (points.isEmpty) return null;
    return _HistorySeries(
      mode: _HistoryMode.step,
      points: points,
      labels: labels,
      minY: -0.5,
      maxY: labels.length <= 1 ? 1.0 : labels.length - 0.5,
    );
  }

  return null;
}

_HistoryMode _historyMode(ThingProperty property) {
  if (property.isNumeric) return _HistoryMode.numeric;
  if (property.type == ThingDataType.boolType ||
      property.type == ThingDataType.enumType) {
    return _HistoryMode.step;
  }
  return _HistoryMode.list;
}

String _formatHistoryValue(ThingProperty property, Object? raw) {
  if (property.type == ThingDataType.boolType) {
    return _asBool(raw) ? '开启' : '关闭';
  }
  if (property.type == ThingDataType.enumType) {
    final key = raw?.toString() ?? '--';
    final label = property.enumValues[key];
    return label == null || label.isEmpty ? key : '$label ($key)';
  }
  final numeric = _numericValue(raw);
  final valueText = numeric == null
      ? _renderRaw(raw)
      : numeric.toStringAsFixed(
          property.type == ThingDataType.int32 ||
                  property.type == ThingDataType.int64
              ? 0
              : 1,
        );
  if (property.unit.isNotEmpty && numeric != null) {
    return '$valueText ${property.unit}';
  }
  return valueText;
}

String _renderRaw(Object? raw) {
  if (raw == null) return '--';
  if (raw is String) return raw.isEmpty ? '--' : raw;
  if (raw is num || raw is bool) return raw.toString();
  try {
    return jsonEncode(raw);
  } catch (_) {
    return raw.toString();
  }
}

double? _numericValue(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
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
