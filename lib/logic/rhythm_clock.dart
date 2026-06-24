/// Đồng hồ nhịp THUẦN cho chế độ Rhythm — tích luỹ thời gian trong game loop
/// (qua [tick]), KHÔNG dùng `DateTime.now()`/`Random` (ràng buộc engine + để
/// test inject được). Phán định "đúng nhịp" theo cửa sổ quanh mốc beat.
class RhythmClock {
  /// Nhịp mỗi phút (beats per minute). Có thể thay đổi trong ván (BPM dynamic).
  double bpm;

  /// Nửa độ rộng cửa sổ "đúng nhịp" (giây) quanh mỗi mốc beat.
  double window;

  double _t = 0;
  int _beats = 0;

  RhythmClock({this.bpm = 100, this.window = 0.14})
    : assert(bpm > 0),
      assert(window > 0);

  double get beatPeriod => 60.0 / bpm;
  int get beatCount => _beats;
  double get time => _t;

  void reset() {
    _t = 0;
    _beats = 0;
  }

  bool tick(double dt) {
    if (dt <= 0) return false;
    _t += dt;
    final n = _t ~/ beatPeriod;
    if (n > _beats) {
      _beats = n;
      return true;
    }
    return false;
  }

  double get phase => (_t % beatPeriod) / beatPeriod;

  /// Khoảng cách (giây) tới mốc beat gần nhất.
  double get distanceToBeat {
    final into = _t % beatPeriod;
    final rest = beatPeriod - into;
    return into < rest ? into : rest;
  }

  bool get onBeat => distanceToBeat <= window;
}

// W21 — BPM dynamic theo groove level (pure functions, không dùng DateTime/Random).

/// BPM theo groove (0-8):
///   0-2  → 80  (slow, easy)
///   3-5  → 100 (baseline)
///   6-7  → 120 (fast)
///   8    → 140 (max, hard)
double rhythmBpmFor(int groove) {
  if (groove >= 8) return 140;
  if (groove >= 6) return 120;
  if (groove >= 3) return 100;
  return 80;
}

/// Judgment window theo groove:
///   0-7  → 0.14s (normal)
///   8    → 0.10s (strict)
double rhythmWindowFor(int groove) => groove >= 8 ? 0.10 : 0.14;

/// Phân loại nhịp theo khoảng cách tới beat.
/// Trả về: 2=PERFECT, 1=GOOD, -1=LATE/EARLY, -2=MISS.
int rhythmJudgeFor(double distance, double window) {
  if (distance > window) return -2; // MISS
  if (distance <= 0.05) return 2; // PERFECT
  if (distance <= 0.10) return 1; // GOOD
  return -1; // LATE/EARLY
}
