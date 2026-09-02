import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:runlog/services/update_service.dart';

class _FakeClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest) _handler;

  _FakeClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request);
}

void main() {
  test('checkLatest requires the named APK, HTTPS URL, and SHA-256 digest', () async {
    final client = _FakeClient((request) async {
      final body = jsonEncode({
        'tag_name': 'v1.6.9',
        'body': 'notes',
        'assets': [
          {
            'name': 'app-debug.apk',
            'browser_download_url': 'https://github.com/example/debug.apk',
            'digest': 'sha256:${'0' * 64}',
          },
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://github.com/example/release.apk',
            'digest': 'sha256:${'a' * 64}',
          },
        ],
      });
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
        contentLength: body.length,
      );
    });

    final info = await UpdateService(client: client).checkLatest();

    expect(info, isNotNull);
    expect(info!.version, '1.6.9');
    expect(info.apkUrl, 'https://github.com/example/release.apk');
    expect(info.sha256, 'a' * 64);
  });

  test('downloadApk rejects a non-200 response without creating an APK', () async {
    final temp = await Directory.systemTemp.createTemp('runlog-update-test-');
    addTearDown(() => temp.delete(recursive: true));
    final client = _FakeClient((request) async => http.StreamedResponse(
          Stream.value(utf8.encode('not found')),
          404,
        ));
    final info = UpdateInfo(
      version: '1.6.9',
      apkUrl: 'https://github.com/example/release.apk',
      notes: '',
      sha256: 'a' * 64,
    );

    await expectLater(
      UpdateService(
        client: client,
        temporaryDirectory: () async => temp,
      ).downloadApk(info, (_) {}),
      throwsA(isA<HttpException>()),
    );
    expect(await File('${temp.path}/runlog-update.apk').exists(), isFalse);
  });

  test('downloadApk rejects a redirect to an untrusted host', () async {
    final temp = await Directory.systemTemp.createTemp('runlog-update-test-');
    addTearDown(() => temp.delete(recursive: true));
    final client = _FakeClient((request) async => http.StreamedResponse(
          Stream<List<int>>.value(const []),
          302,
          headers: {'location': 'https://evil.example/release.apk'},
        ));
    final info = UpdateInfo(
      version: '1.6.9',
      apkUrl: 'https://github.com/example/release.apk',
      notes: '',
      sha256: 'a' * 64,
    );

    await expectLater(
      UpdateService(
        client: client,
        temporaryDirectory: () async => temp,
      ).downloadApk(info, (_) {}),
      throwsA(isA<FormatException>()),
    );
  });

  test('downloadApk follows an allowed GitHub asset redirect', () async {
    final temp = await Directory.systemTemp.createTemp('runlog-update-test-');
    addTearDown(() => temp.delete(recursive: true));
    final payload = utf8.encode('redirected APK fixture');
    final responses = <http.StreamedResponse>[
      http.StreamedResponse(
        Stream<List<int>>.value(const []),
        302,
        headers: {
          'location':
              'https://release-assets.githubusercontent.com/release.apk',
        },
      ),
      http.StreamedResponse(
        Stream.value(payload),
        200,
        contentLength: payload.length,
      ),
    ];
    final client = _FakeClient((request) async => responses.removeAt(0));
    final info = UpdateInfo(
      version: '1.6.9',
      apkUrl: 'https://github.com/example/release.apk',
      notes: '',
      sha256: sha256.convert(payload).toString(),
    );

    final path = await UpdateService(
      client: client,
      temporaryDirectory: () async => temp,
    ).downloadApk(info, (_) {});

    expect(await File(path).readAsBytes(), payload);
  });

  test('downloadApk verifies the streamed SHA-256 digest', () async {
    final temp = await Directory.systemTemp.createTemp('runlog-update-test-');
    addTearDown(() => temp.delete(recursive: true));
    final payload = utf8.encode('local APK fixture');
    final client = _FakeClient((request) async => http.StreamedResponse(
          Stream.value(payload),
          200,
          contentLength: payload.length,
        ));
    final info = UpdateInfo(
      version: '1.6.9',
      apkUrl: 'https://github.com/example/release.apk',
      notes: '',
      sha256: sha256.convert(payload).toString(),
    );

    final path = await UpdateService(
      client: client,
      temporaryDirectory: () async => temp,
    ).downloadApk(info, (_) {});

    expect(await File(path).readAsBytes(), payload);
  });

  test('isNewer compares three numeric version components', () {
    expect(UpdateService.isNewer('1.6.8+20', '1.6.9'), isTrue);
    expect(UpdateService.isNewer('1.6.9', '1.6.9'), isFalse);
    expect(UpdateService.isNewer('1.7.0', '1.6.9'), isFalse);
  });
}
