/// Đồng hồ nhịp THUẦN cho chế độ Rhythm — tích luỹ thời gian trong game loop
/// (qua [tick]), KHÔNG dùng `DateTime.now()`/`Random` (ràng buộc engine + để
/// test inject được). Phán định "đúng nhịp" theo cửa sổ quanh mốc beat.
class RhythmClock {
  /// Nhịp mỗi phút (beats per minute).
  final double bpm;

  /// Nửa độ rộng cửa sổ "đúng nhịp" (giây) quanh mỗi mốc beat.
  /// onBeat = khoảng cách tới mốc beat gần nhất ≤ [window].
  final double window;

  double _t = 0; // tổng thời gian tích luỹ (giây)
  int _beats = 0; // số mốc beat đã đi qua

  RhythmClock({this.bpm = 100, this.window = 0.14})
      : assert(bpm > 0),
        assert(window > 0);

  /// Độ dài 1 beat (giây).
  double get beatPeriod => 60.0 / bpm;

  /// Số mốc beat đã đi qua kể từ [reset].
  int get beatCount => _beats;

  double get time => _t;

  void reset() {
    _t = 0;
    _beats = 0;
  }

  /// Tiến đồng hồ thêm [dt] giây. Trả về true nếu vừa CROSS qua ≥1 mốc beat
  /// (để engine đập HUD / phát tick).
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

  /// Pha trong beat hiện tại, [0, 1).
  double get phase => (_t % beatPeriod) / beatPeriod;

  /// Khoảng cách (giây) tới mốc beat gần nhất (trước hoặc sau).
  double get distanceToBeat {
    final into = _t % beatPeriod;
    final rest = beatPeriod - into;
    return into < rest ? into : rest;
  }

  /// Thời điểm hiện tại có nằm trong cửa sổ "đúng nhịp" không?
  bool get onBeat => distanceToBeat <= window;
}
