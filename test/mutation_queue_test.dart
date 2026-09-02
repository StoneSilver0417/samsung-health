import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runlog/data/mutation_queue.dart';

void main() {
  test('runs a later mutation only after the earlier one completes', () async {
    final queue = MutationQueue();
    final release = Completer<void>();
    final events = <String>[];

    final first = queue.run(() async {
      events.add('first-start');
      await release.future;
      events.add('first-end');
      return 1;
    });
    final second = queue.run(() async {
      events.add('second');
      return 2;
    });

    await Future<void>.value();
    expect(events, ['first-start']);

    release.complete();
    expect(await first, 1);
    expect(await second, 2);
    expect(events, ['first-start', 'first-end', 'second']);
  });
}
