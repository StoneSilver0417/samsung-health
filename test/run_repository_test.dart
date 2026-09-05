import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:runlog/data/run_repository.dart';

void main() {
  test('Hive encryption key accepts exactly 32 decoded bytes', () {
    final encoded = base64UrlEncode(List<int>.generate(32, (i) => i));

    expect(
      HiveRunRepository.decodeEncryptionKey(encoded),
      List<int>.generate(32, (i) => i),
    );
  });

  test('Hive encryption key rejects the wrong decoded length', () {
    final encoded = base64UrlEncode(List<int>.filled(31, 0));

    expect(
      () => HiveRunRepository.decodeEncryptionKey(encoded),
      throwsA(isA<StateError>()),
    );
  });

  test('Hive encryption key rejects invalid base64 format', () {
    expect(
      () => HiveRunRepository.decodeEncryptionKey('invalid!!base64=='),
      throwsA(isA<StateError>()),
    );
  });
}
