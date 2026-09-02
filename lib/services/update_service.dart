import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String version;
  final String apkUrl;
  final String notes;
  final String sha256;
  const UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.notes,
    required this.sha256,
  });
}

/// GitHub Release 기반 앱 업데이트 확인·다운로드·설치.
/// 저장소가 공개 저장소로 전환되어 인증 없이 Releases API 조회 가능
/// (StoneSilver0417/samsung-health). 새 버전 배포 시 태그(v1.x.x)와
/// APK 에셋을 첨부한 GitHub Release 생성이 필수 — 이게 없으면 이 기능은 동작 안 함.
class UpdateService {
  static const _repo = 'StoneSilver0417/samsung-health';
  static const _apkAssetName = 'app-release.apk';
  static const _maxApkBytes = 100 * 1024 * 1024;
  static const _allowedDownloadHosts = {
    'github.com',
    'objects.githubusercontent.com',
    'release-assets.githubusercontent.com',
  };

  static bool _isAllowedDownloadUrl(Uri url) =>
      url.scheme == 'https' && _allowedDownloadHosts.contains(url.host);

  final http.Client _client;
  final Future<Directory> Function() _temporaryDirectory;

  UpdateService({
    http.Client? client,
    Future<Directory> Function()? temporaryDirectory,
  })  : _client = client ?? http.Client(),
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// 최신 릴리즈 조회. 네트워크 오류·릴리즈 없음 등은 전부 null로 조용히 무시.
  Future<UpdateInfo?> checkLatest() async {
    try {
      final res = await _client
          .get(
            Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'RunLog-Update-Checker',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final tag =
          (json['tag_name'] as String? ?? '').replaceFirst(RegExp('^v'), '');
      final assets = json['assets'];
      if (assets is! List) return null;

      Map<String, dynamic>? apk;
      for (final asset in assets) {
        if (asset is! Map) continue;
        final candidate = Map<String, dynamic>.from(asset);
        if (candidate['name'] == _apkAssetName) {
          apk = candidate;
          break;
        }
      }

      final apkUrl = apk?['browser_download_url'] as String?;
      final digest = _normalizeSha256(apk?['digest'] as String?);
      if (tag.isEmpty || apkUrl == null || digest == null) return null;
      final parsedUrl = Uri.tryParse(apkUrl);
      if (parsedUrl == null ||
          parsedUrl.scheme != 'https' ||
          !_allowedDownloadHosts.contains(parsedUrl.host)) {
        return null;
      }
      return UpdateInfo(
        version: tag,
        apkUrl: apkUrl,
        notes: json['body'] as String? ?? '',
        sha256: digest,
      );
    } catch (_) {
      return null;
    }
  }

  /// [current] < [latest]인지 semver(x.y.z) 비교. 빌드번호(+n)는 무시.
  static bool isNewer(String current, String latest) {
    List<int> parts(String v) => v
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final c = parts(current);
    final l = parts(latest);
    for (var i = 0; i < 3; i++) {
      final cv = i < c.length ? c[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (lv != cv) return lv > cv;
    }
    return false;
  }

  /// 검증된 Release APK를 임시 디렉토리에 다운로드하고 로컬 경로를 반환한다.
  Future<String> downloadApk(
      UpdateInfo info, void Function(double progress) onProgress) async {
    final url = Uri.tryParse(info.apkUrl);
    if (url == null || !_isAllowedDownloadUrl(url)) {
      throw const FormatException('허용되지 않은 업데이트 다운로드 주소입니다');
    }

    final dir = await _temporaryDirectory();
    final file = File('${dir.path}/runlog-update.apk');
    final partial = File('${dir.path}/runlog-update.apk.part');
    if (await partial.exists()) await partial.delete();

    late http.StreamedResponse response;
    var downloadUrl = url;
    for (var redirectCount = 0;; redirectCount++) {
      final request = http.Request('GET', downloadUrl)
        ..followRedirects = false
        ..maxRedirects = 0;
      response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 300 || response.statusCode >= 400) break;
      if (redirectCount >= 3) {
        await response.stream.drain<void>();
        throw const FormatException('업데이트 redirect 횟수가 너무 많습니다');
      }
      final location = response.headers['location'];
      await response.stream.drain<void>();
      if (location == null) {
        throw const FormatException('업데이트 redirect 주소가 없습니다');
      }
      downloadUrl = downloadUrl.resolve(location);
      if (!_isAllowedDownloadUrl(downloadUrl)) {
        throw const FormatException('허용되지 않은 업데이트 redirect 주소입니다');
      }
    }
    if (response.statusCode != 200) {
      throw HttpException('업데이트 다운로드 실패 (${response.statusCode})');
    }

    final total = response.contentLength ?? 0;
    if (total > _maxApkBytes) {
      throw const FormatException('업데이트 파일이 너무 큽니다');
    }

    var received = 0;
    final digestSink = AccumulatorSink<Digest>();
    final digestInput = sha256.startChunkedConversion(digestSink);
    final sink = partial.openWrite();
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > _maxApkBytes) {
          throw const FormatException('업데이트 파일이 너무 큽니다');
        }
        sink.add(chunk);
        digestInput.add(chunk);
        if (total > 0) onProgress(received / total);
      }
      digestInput.close();
    } finally {
      await sink.close();
    }

    if (total > 0 && received != total) {
      await partial.delete();
      throw const FormatException('업데이트 파일이 완전히 다운로드되지 않았습니다');
    }

    final actualDigest = digestSink.events.single.toString();
    if (actualDigest != info.sha256) {
      await partial.delete();
      throw const FormatException('업데이트 파일 무결성 검증에 실패했습니다');
    }

    if (await file.exists()) await file.delete();
    await partial.rename(file.path);
    return file.path;
  }

  static String? _normalizeSha256(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    final hex = normalized.startsWith('sha256:')
        ? normalized.substring('sha256:'.length)
        : normalized;
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(hex) ? hex : null;
  }

  /// 다운로드된 APK를 시스템 설치 프로그램으로 연다.
  Future<void> install(String apkPath) async {
    await OpenFilex.open(apkPath);
  }
}
