import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/ui/theme/spacing.dart';

void main() {
  test('Spacing exposes exact AC #2 values as static const double', () {
    expect(Spacing.xs, 4.0);
    expect(Spacing.sm, 8.0);
    expect(Spacing.md, 16.0);
    expect(Spacing.lg, 24.0);
    expect(Spacing.xl, 32.0);
    expect(Spacing.xxl, 48.0);
  });
}
