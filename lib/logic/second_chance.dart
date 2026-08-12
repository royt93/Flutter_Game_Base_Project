/// I88: mua thêm **một** cơ hội khi bàn cạn/kẹt mà chưa đủ target.
///
/// Bàn campaign không refill (Zen là ngoại lệ duy nhất), nên thua là chỉ còn
/// chơi lại từ đầu hoặc thoát — không có gì ở giữa. Chuẩn thể loại giải quyết
/// bằng "xem quảng cáo để chơi tiếp"; dự án này đã chốt **không dùng quảng
/// cáo**, nên đường duy nhất là trả bằng coin đã kiếm được.
///
/// Thuần: không đọc storage/GetX. Toàn bộ điều kiện nằm ở đây để test rẻ.
library;

/// Giá một lần mua, cố định. Cố ý KHÔNG tăng dần theo số lần mua — đó là
/// đường trượt biến cơ chế cứu trợ thành máy hút coin.
const int kSecondChanceCost = 120;

/// Ngưỡng "thua sát nút": chỉ chào mời khi người chơi đạt ít nhất bằng này so
/// với target.
///
/// Dưới ngưỡng thì mua thêm ô cũng không cứu được, và chào lúc đó chỉ khiến
/// người chơi thấy bị moi tiền đúng lúc đang bực. Đây là con số dễ tune nhất
/// của tính năng — chỉnh ở đây, không rải điều kiện ra ngoài.
const double kSecondChanceMinRatio = 0.7;

/// Có được chào mua cơ hội thứ hai không.
///
/// [isCampaign]: cố ý loại mọi side-mode. Các mode dùng best-score mà mua
/// được thêm lượt thì **mọi kỷ lục đều mua được** — hỏng ý nghĩa bảng xếp
/// hạng lẫn thành tựu.
///
/// [alreadyUsedThisLevel]: tối đa 1 lần mỗi màn.
bool canOfferSecondChance({
  required bool isCampaign,
  required int starsEarned,
  required int score,
  required int targetScore,
  required bool alreadyUsedThisLevel,
  required int coins,
}) {
  if (!isCampaign || alreadyUsedThisLevel) return false;
  if (starsEarned > 0) return false; // đã thắng, không cần cứu
  if (targetScore <= 0) return false; // bàn không có target (side/puzzle)
  if (score < targetScore * kSecondChanceMinRatio) return false;
  return coins >= kSecondChanceCost;
}

/// Đã đủ gần target để **đáng** chào, nhưng không đủ xu.
///
/// Tách khỏi [canOfferSecondChance] để UI hiện nút mờ kèm lý do thay vì im
/// lặng — im lặng khiến người chơi tưởng tính năng bị lỗi. Cố ý không đẩy
/// sang cửa hàng: vừa thua mà bị mời mua tiếp là phản cảm.
bool isSecondChanceUnaffordable({
  required bool isCampaign,
  required int starsEarned,
  required int score,
  required int targetScore,
  required bool alreadyUsedThisLevel,
  required int coins,
}) {
  if (!isCampaign || alreadyUsedThisLevel) return false;
  if (starsEarned > 0) return false;
  if (targetScore <= 0) return false;
  if (score < targetScore * kSecondChanceMinRatio) return false;
  return coins < kSecondChanceCost;
}
