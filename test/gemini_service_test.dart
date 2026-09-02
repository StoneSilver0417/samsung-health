import 'package:flutter_test/flutter_test.dart';
import 'package:runlog/models/run_session.dart';
import 'package:runlog/services/gemini_service.dart';

RunSession _run({required double km, required int durationSec}) => RunSession(
      id: '$km-$durationSec',
      startTime: DateTime(2026, 8, 1, 21),
      endTime: DateTime(2026, 8, 1, 21).add(Duration(seconds: durationSec)),
      distanceM: km * 1000,
      durationSec: durationSec,
    );

void main() {
  test('average pace uses only runs with a valid pace', () {
    final average = GeminiService.averagePaceSecPerKm([
      _run(km: 5, durationSec: 1500),
      _run(km: 0, durationSec: 600),
      _run(km: 5, durationSec: 1800),
    ]);

    expect(average, 330);
  });

  test('average pace is absent when every run has no valid pace', () {
    expect(
      GeminiService.averagePaceSecPerKm([_run(km: 0, durationSec: 600)]),
      isNull,
    );
  });
}
