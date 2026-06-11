import 'dart:ui';

/// NRC 스타일 러너 레벨 — 누적 거리 기준 (PRD 1.2 동기부여)
class RunnerLevel {
  final String name;
  final double minKm;
  final Color color;
  final Color colorDark;

  const RunnerLevel(this.name, this.minKm, this.color, this.colorDark);
}

const List<RunnerLevel> kLevels = [
  RunnerLevel('옐로우', 0, Color(0xFFFFE03D), Color(0xFFB89F14)),
  RunnerLevel('오렌지', 50, Color(0xFFFF9A3D), Color(0xFFB5641A)),
  RunnerLevel('그린', 250, Color(0xFF4ADE80), Color(0xFF1E8A4C)),
  RunnerLevel('블루', 1000, Color(0xFF4A9DFF), Color(0xFF1F5FAD)),
  RunnerLevel('퍼플', 2500, Color(0xFFB07AFF), Color(0xFF6A3BBF)),
  RunnerLevel('블랙', 5000, Color(0xFF8B949E), Color(0xFF30363D)),
  RunnerLevel('볼트', 15000, Color(0xFFC8FF3D), Color(0xFF7DA32A)),
];

RunnerLevel levelFor(double totalKm) =>
    kLevels.lastWhere((l) => totalKm >= l.minKm);

/// 다음 레벨. 최고 레벨이면 null.
RunnerLevel? nextLevelFor(double totalKm) {
  final idx = kLevels.indexOf(levelFor(totalKm));
  return idx + 1 < kLevels.length ? kLevels[idx + 1] : null;
}
