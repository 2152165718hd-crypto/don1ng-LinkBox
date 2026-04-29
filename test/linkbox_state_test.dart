import 'package:don1ng_linkbox/runtime/linkbox_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial state treats device as offline until lifecycle confirms it',
      () {
    expect(LinkBoxState.initial().deviceOnline, isFalse);
  });
}
