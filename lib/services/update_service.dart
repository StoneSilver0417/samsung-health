import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String version;
  final String apkUrl;
  final String notes;
  const UpdateInfo(
      {required this.version, required this.apkUrl, required this.notes});
}

/// GitHub Release 기반 앱 업데이트 확인·다운로드·설치.
/// 저장소가 공개 저장소로 전환되어 인증 없이 Releases API 조회 가능
/// (StoneSilver0417/samsung-health). 새 버전 배포 시 태그(v1.x.x)와
/// APK 에셋을 첨부한 GitHub Release 생성이 필수 — 이게 없으면 이 기능은 동작 안 함.
class UpdateService {
  static const _repo = 'StoneSilver0417/samsung-health';

  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// 최신 릴리즈 조회. 네트워크 오류·릴리즈 없음 등은 전부 null로 조용히 무시.
  Future<UpdateInfo?> checkLatest() async {
    try {
      final res = await http
          .get(Uri.parse(
              'https://api.github.com/repos/$_repo/releases/latest'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final tag =
          (json['tag_name'] as String? ?? '').replaceFirst(RegExp('^v'), '');
      final assets = (json['assets'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final apk = assets.cast<Map<String, dynamic>?>().firstWhere(
            (a) => (a?['name'] as String? ?? '').endsWith('.apk'),
            orElse: () => null,
          );
      final apkUrl = apk?['browser_download_url'] as String?;
      if (tag.isEmpty || apkUrl == null) return null;
      return UpdateInfo(
          version: tag, apkUrl: apkUrl, notes: json['body'] as String? ?? '');
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

  /// APK를 임시 디렉토리에 다운로드하고 로컬 경로를 반환한다.
  Future<String> downloadApk(
      String url, void Function(double progress) onProgress) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/runlog-update.apk');
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);
    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = file.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress(received / total);
    }
    await sink.close();
    return file.path;
  }

  /// 다운로드된 APK를 시스템 설치 프로그램으로 연다.
  Future<void> install(String apkPath) async {
    await OpenFilex.open(apkPath);
  }
}
