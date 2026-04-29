import 'package:uuid/uuid.dart';

import '../storage/models.dart';
import 'dashboard_constants.dart';

class DashboardFactory {
  DashboardFactory({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  ({List<DashboardPageConfig> pages, List<DashboardWidgetConfig> widgets})
      buildDefault(
    List<ThingProperty> properties,
  ) {
    return mergeForProperties(
      properties: properties,
      pages: const [],
      widgets: const [],
    );
  }

  ({List<DashboardPageConfig> pages, List<DashboardWidgetConfig> widgets})
      mergeForProperties({
    required List<ThingProperty> properties,
    required List<DashboardPageConfig> pages,
    required List<DashboardWidgetConfig> widgets,
  }) {
    final nextPages = pages.isEmpty
        ? const [DashboardPageConfig(id: 'main', name: '运行面板')]
        : List<DashboardPageConfig>.of(pages);
    final pageId = nextPages.first.id;
    final nextWidgets = List<DashboardWidgetConfig>.of(widgets);
    final dataBindings = nextWidgets
        .where((item) => item.displayMode != DashboardDisplayMode.trendChart)
        .map((item) => item.propertyIdentifier)
        .toSet();
    final chartBindings = nextWidgets
        .where((item) => item.displayMode == DashboardDisplayMode.trendChart)
        .map((item) => item.propertyIdentifier)
        .toSet();

    var nextPosition = _nextPosition(nextWidgets);
    for (final property in properties) {
      if (!dataBindings.contains(property.identifier)) {
        final mode = defaultDisplayModeFor(property);
        nextWidgets.add(
          DashboardWidgetConfig(
            id: _uuid.v4(),
            pageId: pageId,
            type: widgetTypeForDisplayMode(mode),
            propertyIdentifier: property.identifier,
            title: property.displayName,
            x: nextPosition.x,
            y: nextPosition.y,
            width: DashboardLayoutConstants.defaultCardWidth,
            height: DashboardLayoutConstants.defaultCardHeight,
            displayMode: mode,
            iconKind: DashboardIconKind.builtinPng,
            iconValue: defaultBuiltinIconKey(property),
            showUnit: true,
            decimalDigits: property.isNumeric ? 1 : 0,
          ),
        );
        nextPosition = nextPosition.nextCard();
      }
      if (property.isNumeric && !chartBindings.contains(property.identifier)) {
        nextWidgets.add(
          DashboardWidgetConfig(
            id: _uuid.v4(),
            pageId: pageId,
            type: DashboardWidgetType.trendChart,
            propertyIdentifier: property.identifier,
            title: '${property.displayName}趋势',
            x: DashboardLayoutConstants.defaultCardX,
            y: nextPosition.y,
            width: DashboardLayoutConstants.defaultChartWidth,
            height: DashboardLayoutConstants.defaultChartHeight,
            displayMode: DashboardDisplayMode.trendChart,
            iconKind: DashboardIconKind.builtinPng,
            iconValue: defaultBuiltinIconKey(property),
            showUnit: true,
            decimalDigits: property.isNumeric ? 1 : 0,
          ),
        );
        nextPosition = nextPosition.nextChart();
      }
    }

    return (pages: nextPages, widgets: nextWidgets);
  }
}

String defaultBuiltinIconKey(ThingProperty property) {
  final id = '${property.identifier} ${property.name}'.toLowerCase();
  if (id.contains('temp') || id.contains('温度')) return 'temperature';
  if (id.contains('hum') || id.contains('湿度')) return 'humidity';
  if (id.contains('light') || id.contains('illum') || id.contains('光')) {
    return 'light';
  }
  if (id.contains('smoke') || id.contains('gas') || id.contains('烟')) {
    return 'smoke';
  }
  if (id.contains('distance') || id.contains('range') || id.contains('距')) {
    return 'distance';
  }
  if (id.contains('relay') || id.contains('继电器')) return 'relay';
  if (id.contains('switch') || id.contains('led') || id.contains('灯')) {
    return 'switch';
  }
  if (id.contains('motor') || id.contains('电机')) return 'motor';
  return 'device';
}

_DashboardPosition _nextPosition(List<DashboardWidgetConfig> widgets) {
  if (widgets.isEmpty) {
    return const _DashboardPosition(
      DashboardLayoutConstants.defaultCardX,
      DashboardLayoutConstants.defaultCardY,
      0,
    );
  }
  final bottom = widgets.fold<double>(
    DashboardLayoutConstants.defaultCardY,
    (current, item) => item.y +
                item.height +
                DashboardLayoutConstants.canvasBorderPadding >
            current
        ? item.y + item.height + DashboardLayoutConstants.canvasBorderPadding
        : current,
  );
  return _DashboardPosition(DashboardLayoutConstants.defaultCardX, bottom, 0);
}

class _DashboardPosition {
  const _DashboardPosition(this.x, this.y, this.column);

  final double x;
  final double y;
  final int column;

  _DashboardPosition nextCard() {
    if (column == 0) {
      return _DashboardPosition(
        DashboardLayoutConstants.defaultCardX +
            DashboardLayoutConstants.defaultCardWidth +
            DashboardLayoutConstants.cardColumnGap,
        y,
        1,
      );
    }
    return _DashboardPosition(
      DashboardLayoutConstants.defaultCardX,
      y + DashboardLayoutConstants.cardRowHeight,
      0,
    );
  }

  _DashboardPosition nextChart() {
    return _DashboardPosition(
      DashboardLayoutConstants.defaultCardX,
      y + DashboardLayoutConstants.chartRowHeight,
      0,
    );
  }
}
