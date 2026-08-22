import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madogiwa_vrm_lab/main.dart';

void main() {
  test('app entry widget can be constructed', () {
    expect(const VrmLabApp(), isA<StatelessWidget>());
  });
}
