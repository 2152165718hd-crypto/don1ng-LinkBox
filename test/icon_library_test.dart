import 'dart:io';

import 'package:don1ng_linkbox/dashboard/icon_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builtin vector icon library has the planned minimum size', () {
    expect(LinkBoxIconLibrary.materialIcons.length, greaterThanOrEqualTo(50));
    expect(LinkBoxIconLibrary.builtinSvgIcons.length, greaterThanOrEqualTo(16));
    expect(LinkBoxIconLibrary.vectorIconCount, greaterThanOrEqualTo(72));
  });

  test('builtin vector icon keys are unique and svg assets exist', () {
    _expectUnique(LinkBoxIconLibrary.materialIcons.map((item) => item.key));
    _expectUnique(LinkBoxIconLibrary.builtinSvgIcons.map((item) => item.key));

    for (final icon in LinkBoxIconLibrary.builtinSvgIcons) {
      expect(icon.asset.endsWith('.svg'), isTrue);
      expect(File(icon.asset).existsSync(), isTrue,
          reason: '${icon.key} asset missing: ${icon.asset}');
    }
  });
}

void _expectUnique(Iterable<String> keys) {
  final list = keys.toList();
  expect(list.toSet(), hasLength(list.length));
}
