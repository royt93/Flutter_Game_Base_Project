/// I86: vài dòng "bạn đã bỏ lỡ gì" kèm phần thưởng quay lại (I10).
///
/// Popup comeback hiện tại chỉ nói "đây, cầm tiền" — không cho người chơi lý
/// do nào để chơi ván tiếp theo. Digest lấp chỗ đó bằng **số liệu cụ thể** từ
/// dữ liệu đã có sẵn trong máy: không network, không AI, không sinh văn.
///
/// Cố ý tránh câu cảm xúc do máy ghép ("chúng tôi nhớ bạn!") — câu số liệu
/// ("còn 2 sao nữa là mở rương") có tác dụng hơn và không bao giờ nghe sáo.
///
/// Thuần: không đọc storage/GetX/đồng hồ.
library;

/// Một dòng digest: key i18n + tham số để UI ghép chuỗi.
class DigestLine {
  const DigestLine(this.key, {this.params = const {}});

  final String key;
  final Map<String, String> params;

  @override
  bool operator ==(Object other) =>
      other is DigestLine &&
      other.key == key &&
      other.params.length == params.length &&
      other.params.entries.every((e) => params[e.key] == e.value);

  @override
  int get hashCode => Object.hash(key, params.length);

  @override
  String toString() => 'DigestLine($key, $params)';
}

/// Tối đa 3 dòng. Nhiều hơn thì popup thành bức tường chữ, người chơi bấm
/// đóng mà không đọc — đúng thứ digest sinh ra để tránh.
const int kMaxDigestLines = 3;

/// Dựng digest cho người chơi vừa quay lại sau [daysAway] ngày.
///
/// Chỉ trả về dòng **đúng và còn ý nghĩa**: không nhắc rương đã nhận, không
/// nhắc mùa vừa reset. Rỗng là hợp lệ — UI khi đó chỉ hiện phần thưởng như
/// cũ, KHÔNG hiện khung digest trống.
List<DigestLine> buildComebackDigest({
  required int daysAway,
  required int totalStars,
  required int nextChestStars,
  required int weeklyGoalProgress,
  required int weeklyGoalTarget,
  required int seasonDaysLeft,
  required int unlockedLevel,
  required int levelCount,
}) {
  final out = <DigestLine>[];

  void add(String key, [Map<String, String> params = const {}]) {
    if (out.length < kMaxDigestLines) out.add(DigestLine(key, params: params));
  }

  if (daysAway > 0) {
    add('digest_days_away', {'n': '$daysAway'});
  }

  // Rương kế tiếp: chỉ nhắc khi CÒN rương chưa đạt. `nextChestStars <= 0`
  // nghĩa là đã nhận hết mốc — nhắc nữa là sai.
  if (nextChestStars > 0 && totalStars < nextChestStars) {
    add('digest_stars_to_chest', {'n': '${nextChestStars - totalStars}'});
  }

  // Mục tiêu tuần: chỉ nhắc khi đã bắt đầu nhưng chưa xong. Chưa đóng góp gì
  // thì câu "còn 300/300" không nói lên điều gì.
  if (weeklyGoalTarget > 0 &&
      weeklyGoalProgress > 0 &&
      weeklyGoalProgress < weeklyGoalTarget) {
    add('digest_weekly_left', {
      'n': '${weeklyGoalTarget - weeklyGoalProgress}',
    });
  }

  // Mùa: chỉ nhắc khi sắp hết, lúc đó mới là thông tin đáng hành động.
  if (seasonDaysLeft > 0 && seasonDaysLeft <= 7) {
    add('digest_season_ending', {'n': '$seasonDaysLeft'});
  }

  // Tiến độ campaign — phương án cuối, luôn đúng nếu còn màn để chơi.
  if (unlockedLevel <= levelCount) {
    add('digest_next_level', {'n': '$unlockedLevel'});
  }

  return out;
}
