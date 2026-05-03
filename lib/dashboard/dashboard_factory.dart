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
    final nextWidgets = List<DashboardWidgetConfig>.of(
      widgets.where(
        (item) => item.displayMode != DashboardDisplayMode.trendChart,
      ),
    );
    final dataBindings =
        nextWidgets.map((item) => item.propertyIdentifier).toSet();

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
            iconKind: DashboardIconKind.builtinSvg,
            iconValue: defaultBuiltinIconKey(property),
            showUnit: true,
            decimalDigits: property.isNumeric ? 1 : 0,
          ),
        );
        nextPosition = nextPosition.nextCard();
      }
    }

    return (pages: nextPages, widgets: nextWidgets);
  }
}

String defaultBuiltinIconKey(ThingProperty property) {
  final id = '${property.identifier} ${property.name}'.toLowerCase();
  if (id.contains('temp') || id.contains('温度')) return 'svg_temperature';
  if (id.contains('hum') || id.contains('湿度')) return 'svg_humidity';
  if (id.contains('light') || id.contains('illum') || id.contains('光')) {
    return 'svg_light';
  }
  if (id.contains('smoke') || id.contains('gas') || id.contains('烟')) {
    return 'svg_smoke';
  }
  if (id.contains('distance') || id.contains('range') || id.contains('距')) {
    return 'svg_distance';
  }
  if (id.contains('relay') || id.contains('继电器')) return 'svg_relay';
  if (id.contains('switch') || id.contains('led') || id.contains('灯')) {
    return 'svg_switch';
  }
  if (id.contains('motor') || id.contains('电机')) return 'svg_motor';
  if (id.contains('battery') || id.contains('电池')) return 'svg_battery';
  if (id.contains('camera') || id.contains('video') || id.contains('摄像')) {
    return 'svg_camera';
  }
  if (id.contains('lock') || id.contains('door') || id.contains('门锁')) {
    return 'svg_lock';
  }
  return 'svg_device';
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
}
