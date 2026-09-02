import 'package:flutter_test/flutter_test.dart';
import 'package:runlog/ui/analysis_screen.dart';

void main() {
  test('equal pace values receive a non-degenerate chart range', () {
    expect(AnalysisScreen.safePaceRange([6.0, 6.0]), (5.5, 6.5));
  });

  test('different pace values keep half-minute grid alignment', () {
    expect(AnalysisScreen.safePaceRange([5.1, 6.2]), (5.0, 6.5));
  });
}
