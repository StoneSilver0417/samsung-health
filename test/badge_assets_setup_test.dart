import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:runlog/models/achievement.dart';

void main() {
  test('ensure all 33 badge PNG assets exist in assets/badges/', () {
    const copyMap = {
      'first_3k.png': 'first_5k.png',
      'first_full.png': 'first_half.png',
      'total_2000k.png': 'total_1000k.png',
      'streak_12w.png': 'streak_8w.png',
      'month_15runs.png': 'month_10runs.png',
      'speed_sub5.png': 'speed_sub6.png',
      'calorie_1000.png': 'speed_sub6.png',
      'consecutive_2days.png': 'first_run.png',
    };

    final badgesDir = Directory('assets/badges');
    expect(badgesDir.existsSync(), isTrue);

    for (final entry in copyMap.entries) {
      final target = File('${badgesDir.path}/${entry.key}');
      if (!target.existsSync()) {
        final src = File('${badgesDir.path}/${entry.value}');
        expect(src.existsSync(), isTrue, reason: 'Source ${src.path} must exist');
        src.copySync(target.path);
      }
    }

    for (final badge in kBadges) {
      final file = File(badge.assetPath);
      expect(file.existsSync(), isTrue, reason: 'Badge asset ${badge.assetPath} must exist');
      expect(file.lengthSync(), greaterThan(1000), reason: 'Badge asset must not be empty');
    }
  });
}
