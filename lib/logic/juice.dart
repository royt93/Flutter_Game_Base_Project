/// Game-feel "juice" — thang cường độ hiệu ứng theo độ sâu combo (Wave 22.1).
/// PURE Dart (không Flame/Flutter) → unit-test cô lập. Quyết định shake/flash/
/// slow-mo/haptic cho mỗi mức combo; tầng game chỉ ÁNH XẠ ra hiệu ứng thật.
library;

/// Mức haptic ánh xạ sang HapticFeedback ở tầng presentation.
enum JuiceHaptic { light, medium, heavy }

/// Tham số juice cho 1 lần resolve combo. Bất biến, dễ test.
class JuiceTier {
  final double shake; // cường độ rung (đơn vị như _shake hiện tại)
  final double flash; // đỉnh flash (0 = không flash)
  final bool slowmo; // có kích slow-mo không (chỉ wombo)
  final JuiceHaptic haptic;
  const JuiceTier({
    required this.shake,
    required this.flash,
    required this.slowmo,
    required this.haptic,
  });
}

/// Ngưỡng wombo (combo lớn nhất) — đồng bộ với audio arpeggio + slow-mo.
const int kWomboCombo = 6;

/// Thang cường độ theo [combo] (số bước cascade). Leo dần, không nhảy bậc:
/// - <3: không shake/flash (haptic nhẹ)
/// - 3: shake nhẹ + flash mờ
/// - 4–5: shake vừa + flash + haptic vừa
/// - >=6: WOMBO — shake mạnh + flash đậm + slow-mo + haptic mạnh
JuiceTier juiceTierFor(int combo) {
  if (combo >= kWomboCombo) {
    return const JuiceTier(
      shake: 12,
      flash: 0.32,
      slowmo: true,
      haptic: JuiceHaptic.heavy,
    );
  }
  if (combo >= 4) {
    return const JuiceTier(
      shake: 7,
      flash: 0.18,
      slowmo: false,
      haptic: JuiceHaptic.medium,
    );
  }
  if (combo == 3) {
    return const JuiceTier(
      shake: 4,
      flash: 0.12,
      slowmo: false,
      haptic: JuiceHaptic.light,
    );
  }
  return const JuiceTier(
    shake: 0,
    flash: 0,
    slowmo: false,
    haptic: JuiceHaptic.light,
  );
}

/// W22.1.1 — số hạt trail phát khi gem RƠI trong 1 frame. [fallDist] = quãng rơi (px),
/// [cellSize] = cạnh ô. Chỉ phát khi rơi đủ nhanh (≥0.6 ô) & KHÔNG giảm-hiệu-ứng.
/// Cap 2 hạt/frame/gem (chống bão particle khi cascade dài). 0 = không phát.
int trailParticlesFor(
  double fallDist,
  double cellSize, {
  required bool reduced,
}) {
  if (reduced || cellSize <= 0) return 0;
  if (fallDist < cellSize * 0.6) return 0;
  return fallDist > cellSize * 1.5 ? 2 : 1;
}

/// Khi bật "giảm hiệu ứng động" (accessibility): tắt slow-mo, giảm shake 50%,
/// giảm flash. Trả về tier đã làm dịu. Haptic giữ nguyên (không gây chóng mặt).
JuiceTier dampenJuice(JuiceTier t, {required bool reduced}) {
  if (!reduced) return t;
  return JuiceTier(
    shake: t.shake * 0.5,
    flash: t.flash * 0.4,
    slowmo: false,
    haptic: t.haptic,
  );
}
