import 'package:flutter_test/flutter_test.dart';
import 'package:runlog/ui/manual_add_screen.dart';

void main() {
  test('new manual runs at the same start minute receive different IDs', () {
    final start = DateTime(2026, 8, 1, 21, 30);
    final first = manualRunId(start, DateTime(2026, 8, 2, 10, 0, 0, 0, 1));
    final second = manualRunId(start, DateTime(2026, 8, 2, 10, 0, 0, 0, 2));

    expect(first, isNot(second));
    expect(first, startsWith('manual-${start.millisecondsSinceEpoch}-'));
  });
}
