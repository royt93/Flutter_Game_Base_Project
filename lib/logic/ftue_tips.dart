/// I85: các mẩu hướng dẫn ngắn dạy **luật lõi** mà FTUE cũ (X1) không dạy.
///
/// FTUE hiện có chỉ làm đúng một việc: gợi ý một nhóm nên tap ở level 1, rồi
/// tắt vĩnh viễn ngay tap đầu tiên. Người chơi vẫn không được dạy:
/// - nhóm càng lớn điểm càng cao (`scoreForGroup` là siêu tuyến tính);
/// - bàn **không refill** — mỗi ô là hữu hạn.
///
/// Điều thứ hai quan trọng và phản trực giác nhất: người quen Candy Crush cho
/// rằng bàn tự đầy lại, nên chơi phung phí rồi thua mà không hiểu vì sao.
///
/// Thuần: mỗi mẩu là một vị từ nhận state làm tham số. Không đọc storage,
/// không GetX — nhờ vậy khoá được toàn bộ luật "khi nào hiện" bằng test rẻ,
/// và tầng UI chỉ còn việc vẽ.
library;

/// Mẩu hướng dẫn — mỗi cái tắt độc lập và vĩnh viễn, có key `hasSeen*` riêng.
enum FtueTip {
  /// Level 1: nhóm càng lớn càng nhiều điểm.
  biggerGroups,

  /// Lần thua đầu tiên: bàn không refill, gom nhóm lớn hơn trước khi nổ.
  noRefill,
}

/// Level cao nhất còn hiện mẩu "nhóm lớn hơn = nhiều điểm hơn".
///
/// Chỉ level 1: sang màn 2 là người chơi đã tự nổ vài nhóm rồi, nhắc nữa
/// thành phiền.
const int kBiggerGroupsTipMaxLevel = 1;

/// Có hiện mẩu "nhóm càng lớn điểm càng cao" không.
///
/// [skipAllTips] là công tắc "Bỏ qua hướng dẫn" trong Settings — dành cho
/// người chơi cũ cài lại, nó tắt mọi mẩu chứ không riêng mẩu này.
bool shouldShowBiggerGroupsTip({
  required bool isCampaign,
  required int levelId,
  required bool alreadySeen,
  required bool skipAllTips,
}) {
  if (skipAllTips || alreadySeen || !isCampaign) return false;
  return levelId <= kBiggerGroupsTipMaxLevel;
}

/// Có hiện mẩu "bàn không refill" ở màn thua không.
///
/// Chỉ tính là "thua" khi kết thúc campaign mà **không đạt sao nào**. Cố ý
/// KHÔNG hiện ở side-mode: Zen có refill (ngoại lệ duy nhất trong game) nên
/// câu này sẽ sai, còn Time Attack/Endless thua vì hết giờ chứ không phải vì
/// cạn ô — nói "bàn không refill" ở đó là dạy nhầm nguyên nhân.
bool shouldShowNoRefillTip({
  required bool isCampaign,
  required int starsEarned,
  required bool alreadySeen,
  required bool skipAllTips,
}) {
  if (skipAllTips || alreadySeen || !isCampaign) return false;
  return starsEarned <= 0;
}

/// Gợi ý cụ thể kèm theo mẩu [FtueTip.noRefill], chọn theo mức độ hụt điểm.
///
/// Nói "hãy gom nhóm lớn hơn" với người chỉ thiếu vài điểm là vô ích; ngược
/// lại người thiếu quá nửa target cần lời khuyên mạnh hơn "cố thêm chút".
FtueLossAdvice lossAdviceFor({required int score, required int targetScore}) {
  if (targetScore <= 0) return FtueLossAdvice.biggerGroups;
  final ratio = score / targetScore;
  if (ratio >= 0.85) return FtueLossAdvice.soClose;
  if (ratio >= 0.5) return FtueLossAdvice.biggerGroups;
  return FtueLossAdvice.planAhead;
}

enum FtueLossAdvice {
  /// Sát nút — chỉ cần một nhóm lớn nữa.
  soClose,

  /// Gom nhóm lớn hơn trước khi nổ.
  biggerGroups,

  /// Còn xa: nhắc rằng bàn hữu hạn, phải tính trước.
  planAhead,
}
