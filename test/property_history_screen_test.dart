import 'dart:async';

import 'package:don1ng_linkbox/dashboard/dashboard_widgets.dart';
import 'package:don1ng_linkbox/runtime/linkbox_controller.dart';
import 'package:don1ng_linkbox/runtime/property_history_screen.dart';
import 'package:don1ng_linkbox/storage/models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const numericProperty = ThingProperty(
    identifier: 'Temp',
    name: '温度',
    type: ThingDataType.float,
    accessMode: AccessMode.readOnly,
    unit: '°C',
    rawType: 'float',
  );
  const boolProperty = ThingProperty(
    identifier: 'Relay',
    name: '继电器',
    type: ThingDataType.boolType,
    accessMode: AccessMode.readOnly,
    rawType: 'bool',
  );
  const textProperty = ThingProperty(
    identifier: 'Note',
    name: '备注',
    type: ThingDataType.stringType,
    accessMode: AccessMode.readOnly,
    rawType: 'string',
  );
  const enumProperty = ThingProperty(
    identifier: 'Mode',
    name: '模式',
    type: ThingDataType.enumType,
    accessMode: AccessMode.readOnly,
    enumValues: {
      '0': '手动',
      '1': '自动',
    },
    rawType: 'enum',
  );

  testWidgets('renders numeric history as a line chart', (tester) async {
    final controller = _HistoryController(
      history: [
        RuntimeValue(identifier: 'Temp', value: 20.5, time: _t0),
        RuntimeValue(identifier: 'Temp', value: 22.2, time: _t1),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PropertyHistoryScreen(
          controller: controller,
          property: numericProperty,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.single.isStepLineChart, isFalse);
  });

  testWidgets('renders bool history as a step chart', (tester) async {
    final controller = _HistoryController(
      history: [
        RuntimeValue(identifier: 'Relay', value: false, time: _t0),
        RuntimeValue(identifier: 'Relay', value: true, time: _t1),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PropertyHistoryScreen(
          controller: controller,
          property: boolProperty,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.single.isStepLineChart, isTrue);
  });

  testWidgets('renders enum history as a step chart', (tester) async {
    final controller = _HistoryController(
      history: [
        RuntimeValue(identifier: 'Mode', value: '0', time: _t0),
        RuntimeValue(identifier: 'Mode', value: '1', time: _t1),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PropertyHistoryScreen(
          controller: controller,
          property: enumProperty,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.single.isStepLineChart, isTrue);
  });

  testWidgets('renders text history as a list', (tester) async {
    final controller = _HistoryController(
      history: [
        RuntimeValue(identifier: 'Note', value: 'first', time: _t0),
        RuntimeValue(identifier: 'Note', value: 'second', time: _t1),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PropertyHistoryScreen(
          controller: controller,
          property: textProperty,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('second'), findsNWidgets(2));
    expect(find.text('first'), findsOneWidget);
    expect(find.text('历史记录'), findsOneWidget);
  });

  testWidgets('shows loading and empty states', (tester) async {
    final completer = Completer<List<RuntimeValue>>();
    final controller = _HistoryController(
      historyFuture: completer.future,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PropertyHistoryScreen(
          controller: controller,
          property: numericProperty,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('暂无历史数据'), findsOneWidget);
  });

  testWidgets('opens history screen from a realtime card', (tester) async {
    final controller = _HistoryController(
      history: [
        RuntimeValue(identifier: 'Temp', value: 18.1, time: _t0),
        RuntimeValue(identifier: 'Temp', value: 19.7, time: _t1),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: SizedBox(
                  width: 220,
                  height: 140,
                  child: DashboardTile(
                    config: const DashboardWidgetConfig(
                      id: 'temp_card',
                      pageId: 'main',
                      type: DashboardWidgetType.valueCard,
                      propertyIdentifier: 'Temp',
                      title: '温度',
                      x: 0,
                      y: 0,
                      width: 220,
                      height: 140,
                      displayMode: DashboardDisplayMode.value,
                    ),
                    property: numericProperty,
                    value: RuntimeValue(
                      identifier: 'Temp',
                      value: 19.7,
                      time: _t1,
                    ),
                    controller: controller,
                    onHistoryTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PropertyHistoryScreen(
                            controller: controller,
                            property: numericProperty,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.byType(DashboardTile)));
    await tester.pumpAndSettle();

    expect(find.byType(PropertyHistoryScreen), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });
}

class _HistoryController extends LinkBoxController {
  _HistoryController({
    List<RuntimeValue> history = const [],
    Future<List<RuntimeValue>>? historyFuture,
  })  : _history = List<RuntimeValue>.of(history),
        _historyFuture = historyFuture,
        super() {
    state = state.copyWith(
      config: const ProjectConfig(
        projectId: 'project',
        groupId: 'group',
        accessKey: 'key',
        productId: 'product',
        deviceName: 'device',
        historyDays: 7,
      ),
      values: {
        for (final value in history) value.identifier: value,
      },
    );
  }

  final List<RuntimeValue> _history;
  final Future<List<RuntimeValue>>? _historyFuture;

  @override
  Future<List<RuntimeValue>> loadHistory(ThingProperty property) {
    return _historyFuture ?? Future<List<RuntimeValue>>.value(_history);
  }
}

final _t0 = DateTime(2026, 5, 3, 8, 0, 0);
final _t1 = DateTime(2026, 5, 3, 8, 5, 0);
