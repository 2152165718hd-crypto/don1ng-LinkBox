import 'package:don1ng_linkbox/dashboard/dashboard_factory.dart';
import 'package:don1ng_linkbox/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard widget config backfills v1 fields', () {
    final config = DashboardWidgetConfig.fromMap({
      'id': 'w1',
      'page_id': 'main',
      'type': 'slider',
      'property_identifier': 'Speed',
      'title': '速度',
      'x': 10.0,
      'y': 20.0,
      'width': 180.0,
      'height': 120.0,
    });

    expect(config.displayMode, DashboardDisplayMode.slider);
    expect(config.iconKind, DashboardIconKind.material);
    expect(config.showUnit, isTrue);
    expect(config.decimalDigits, 1);
    expect(config.backgroundColor, 0xFFFFFFFF);
    expect(config.textColor, 0xFF101828);
  });

  test('display modes are filtered by property type and write access', () {
    const readOnlyNumber = ThingProperty(
      identifier: 'Temp',
      name: '温度',
      type: ThingDataType.float,
      accessMode: AccessMode.readOnly,
      rawType: 'float',
    );
    const writableNumber = ThingProperty(
      identifier: 'Speed',
      name: '速度',
      type: ThingDataType.int32,
      accessMode: AccessMode.readWrite,
      rawType: 'int32',
    );
    const readOnlyBool = ThingProperty(
      identifier: 'Online',
      name: '在线',
      type: ThingDataType.boolType,
      accessMode: AccessMode.readOnly,
      rawType: 'bool',
    );
    const writableBool = ThingProperty(
      identifier: 'Relay',
      name: '继电器',
      type: ThingDataType.boolType,
      accessMode: AccessMode.readWrite,
      rawType: 'bool',
    );

    expect(compatibleDisplayModes(readOnlyNumber),
        isNot(contains(DashboardDisplayMode.slider)));
    expect(compatibleDisplayModes(writableNumber),
        contains(DashboardDisplayMode.slider));
    expect(compatibleDisplayModes(readOnlyBool),
        isNot(contains(DashboardDisplayMode.switcher)));
    expect(compatibleDisplayModes(readOnlyBool),
        isNot(contains(DashboardDisplayMode.button)));
    expect(compatibleDisplayModes(writableBool),
        contains(DashboardDisplayMode.switcher));
  });

  test(
      'dashboard factory creates data cards and numeric trend charts without duplicates',
      () {
    const temp = ThingProperty(
      identifier: 'Temp',
      name: '温度',
      type: ThingDataType.float,
      accessMode: AccessMode.readOnly,
      rawType: 'float',
    );
    const relay = ThingProperty(
      identifier: 'Relay',
      name: '继电器',
      type: ThingDataType.boolType,
      accessMode: AccessMode.readWrite,
      rawType: 'bool',
    );

    final factory = DashboardFactory();
    final first = factory.mergeForProperties(
        properties: const [temp, relay], pages: const [], widgets: const []);

    expect(first.pages, hasLength(1));
    expect(_widgetsFor(first.widgets, 'Temp', trend: false), hasLength(1));
    expect(_widgetsFor(first.widgets, 'Temp', trend: true), hasLength(1));
    expect(_widgetsFor(first.widgets, 'Relay', trend: false), hasLength(1));
    expect(_widgetsFor(first.widgets, 'Relay', trend: true), isEmpty);

    final existingTemp = _widgetsFor(first.widgets, 'Temp', trend: false)
        .single
        .copyWith(width: 222);
    final merged = factory.mergeForProperties(
      properties: const [temp, relay],
      pages: first.pages,
      widgets: [existingTemp],
    );

    expect(_widgetsFor(merged.widgets, 'Temp', trend: false), hasLength(1));
    expect(_widgetsFor(merged.widgets, 'Temp', trend: false).single.width, 222);
    expect(_widgetsFor(merged.widgets, 'Temp', trend: true), hasLength(1));
    expect(_widgetsFor(merged.widgets, 'Relay', trend: false), hasLength(1));
  });
}

List<DashboardWidgetConfig> _widgetsFor(
  List<DashboardWidgetConfig> widgets,
  String identifier, {
  required bool trend,
}) {
  return widgets
      .where(
        (item) =>
            item.propertyIdentifier == identifier &&
            (item.displayMode == DashboardDisplayMode.trendChart) == trend,
      )
      .toList();
}
