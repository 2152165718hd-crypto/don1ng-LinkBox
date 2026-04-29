import 'package:uuid/uuid.dart';

import '../storage/models.dart';

class DashboardFactory {
  DashboardFactory({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  ({List<DashboardPageConfig> pages, List<DashboardWidgetConfig> widgets}) buildDefault(
    List<ThingProperty> properties,
  ) {
    const pageId = 'main';
    final widgets = <DashboardWidgetConfig>[];
    var x = 16.0;
    var y = 16.0;
    var column = 0;

    for (final property in properties) {
      final type = _typeFor(property);
      widgets.add(
        DashboardWidgetConfig(
          id: _uuid.v4(),
          pageId: pageId,
          type: type,
          propertyIdentifier: property.identifier,
          title: property.displayName,
          x: x,
          y: y,
          width: 168,
          height: type == DashboardWidgetType.trendChart ? 180 : 116,
        ),
      );
      column += 1;
      if (column == 2) {
        column = 0;
        x = 16;
        y += 132;
      } else {
        x += 184;
      }
    }

    final firstNumeric = properties.where((item) => item.isNumeric).take(2);
    for (final property in firstNumeric) {
      widgets.add(
        DashboardWidgetConfig(
          id: _uuid.v4(),
          pageId: pageId,
          type: DashboardWidgetType.trendChart,
          propertyIdentifier: property.identifier,
          title: '${property.displayName}趋势',
          x: 16,
          y: y,
          width: 352,
          height: 190,
        ),
      );
      y += 206;
    }

    return (
      pages: const [
        DashboardPageConfig(id: pageId, name: '运行面板'),
      ],
      widgets: widgets,
    );
  }

  DashboardWidgetType _typeFor(ThingProperty property) {
    if (!property.writable) return DashboardWidgetType.valueCard;
    switch (property.type) {
      case ThingDataType.boolType:
        return DashboardWidgetType.switchControl;
      case ThingDataType.enumType:
        return DashboardWidgetType.enumSelect;
      case ThingDataType.int32:
      case ThingDataType.int64:
      case ThingDataType.float:
      case ThingDataType.doubleType:
        return DashboardWidgetType.slider;
      case ThingDataType.stringType:
      case ThingDataType.struct:
      case ThingDataType.bitmap:
      case ThingDataType.unknown:
        return DashboardWidgetType.valueCard;
    }
  }
}
