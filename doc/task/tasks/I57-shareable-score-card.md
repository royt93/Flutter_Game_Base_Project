# I57 — Shareable Score Card

**Epic:** Cảm giác/A-V (viral) · **SP:** 3 · **Pri:** Could
· **Deps:** F15 (Photo Mode / chia sẻ bàn chơi), I30 (Mascot Wardrobe)

## Mục tiêu

Sau khi thắng 1 level/daily-challenge, tạo 1 ảnh "thẻ kết quả" tổng hợp
(điểm, tổng sao, rank leaderboard offline nếu có, mascot skin đang mặc) —
tách biệt với ảnh chụp board của F15 — rồi share ra ngoài app.

## Vì sao

F15 (Photo Mode) chỉ chụp board hiện tại, không truyền tải "thành tích cá
nhân" dễ hiểu khi người ngoài xem trên mạng xã hội. Score card dạng
infographic là đòn bẩy viral mạnh hơn, tái dùng nguyên vẹn dữ liệu
(mascot skin, tổng sao, rank) đã có sẵn.

## Acceptance criteria

- [ ] Widget mới `lib/presentation/widgets/score_card.dart` — bố cục cố
  định (mascot đang active + điểm level vừa thắng + tổng sao + rank
  offline nếu mode hiện tại có leaderboard), bọc trong `RepaintBoundary`
  với `GlobalKey` riêng.
- [ ] Vì `ShareHelper.captureBoardPng()` (`lib/core/share_helper.dart`
  dòng 21-35) yêu cầu widget đã tồn tại trong tree qua `boundaryKey` —
  dựng `ScoreCard` tạm trong 1 overlay ẩn (`Offstage`/render tạm qua
  `NeonDialog.overlay`) ngay trước khi capture, KHÔNG refactor
  `share_helper.dart` để nhận `Widget` trực tiếp (giữ nguyên API cũ,
  tránh phá F15 đang chạy ổn định).
- [ ] Hàm mới `shareScoreCard({required GlobalKey boundaryKey, required
  String levelText})` trong `share_helper.dart`, tái dùng
  `_withTextOverlay`/`shareBoardImage` pattern (dòng 37-87).
- [ ] Dữ liệu card lấy từ `GameController.activeMascotSkin` (dòng
  307-313), `totalStars` (dòng 482, 823), và `playerRank()`/
  `buildLeaderboard()` (`lib/logic/leaderboard.dart` dòng 14-35) nếu mode
  hiện tại có bảng xếp hạng offline (dailyChallenge/gauntlet/
  weeklyFeatured).
- [ ] Nút "Chia sẻ kết quả" xuất hiện trên màn thắng level (win dialog),
  cạnh nút share board (F15) đã có — thêm lựa chọn thứ 2, không thay thế.
- [ ] Card không ảnh hưởng gameplay/điểm số — thuần hiển thị + share,
  chỉ đọc dữ liệu đã có.
- [ ] Widget test `test/presentation/widgets/score_card_test.dart`: card
  hiển thị đúng điểm/sao/skin truyền vào (không test phần capture
  PNG/share thật, chỉ test build widget).
- [ ] i18n nhãn "Chia sẻ kết quả" + text trong card, đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Gap quan trọng: `captureBoardPng` hiện chỉ nhận `boundaryKey` của
  widget đã có trong tree — không refactor thành nhận `Widget` trực tiếp
  (rủi ro phá F15), thay vào đó dựng `ScoreCard` tạm trong overlay ẩn
  ngay trước khi share rồi dispose ngay sau khi capture xong.
- Rank chỉ hiển thị khi mode có leaderboard offline (I9/I33/I38) — mode
  campaign thường không có rank, card cần ẩn dòng rank thay vì hiện
  "N/A" khi rank null.

DoD chung: `../README.md`.
