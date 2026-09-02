import 'dart:async';

class MutationQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() mutation) {
    final next = _tail.then((_) => mutation());
    final tail = Completer<void>();
    next.then<void>(
      (_) => tail.complete(),
      onError: (Object _, StackTrace _) => tail.complete(),
    );
    _tail = tail.future;
    return next;
  }
}
