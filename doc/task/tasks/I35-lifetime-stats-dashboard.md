# I35 — Lifetime Stats Dashboard

**Epic:** Meta/retention · **SP:** 3 · **Pri:** Could · **Deps:** không

## Mục tiêu
Thêm 1 màn hình thống kê trọn đời (`StatsScreen`) hiển thị các con số tích
luỹ đã có sẵn trong `GameController` (tổng gem đã nổ, combo cao nhất, số màn
3 sao, số bàn dọn sạch, số booster đã dùng, tổng coin đã kiếm...) dưới dạng
danh sách số liệu — thuần đọc, không thêm state mới.

## Vì sao
5 metric của hệ thống achievement (`I22`) đã âm thầm track đủ lâu nhưng người
chơi chỉ thấy chúng gián tiếp qua tiến độ achievement, không có nơi xem số
tuyệt đối. Đây là màn hình "vanity" rẻ nhất trong cả đợt (không logic mới),
tăng cảm giác tiến bộ dài hạn — một dạng "vòng lặp thoả mãn" nhẹ, đúng khuyến
nghị chung của game thiết kế retention.

## Acceptance criteria
- [ ] `lib/presentation/screens/stats_screen.dart` (mới): liệt kê tất cả giá
      trị đã có trong `GameController` — `totalGemsPopped`, `maxComboEver`,
      `levelsThreeStarred`, `boardsFullyCleared`, `totalBoostersUsed`, thêm
      1-2 con số tổng hợp suy ra được (ví dụ tổng coin đã kiếm trọn đời — nếu
      chưa có field riêng, thêm `RxInt lifetimeCoinsEarned` cộng dồn tại mọi
      điểm cộng coin hiện có: `checkEnd` thắng màn, comeback bonus, weekend
      event, achievement reward, prestige reward — dùng 1 helper duy nhất
      `_earnCoins(int amount)` thay thế các chỗ gọi `coins.value +=` trực
      tiếp để đảm bảo không sót điểm cộng).
- [ ] `StorageKeys.lifetimeCoinsEarned` (mới, chỉ nếu thêm field trên) —
      lưu/khôi phục giống pattern các `RxInt` khác trong `_loadStats()`
      (tên hàm load hiện có trong `game_controller.dart`, khoảng dòng nạp
      `totalGemsPopped`/`maxComboEver`/...).
- [ ] Entry point: nút/card ở `HomeScreen` hoặc gộp chung vào `TrophyRoomScreen`
      (`I34`, nếu I34 được làm trước — không bắt buộc phụ thuộc, có thể tách
      route riêng nếu I34 chưa tồn tại).
- [ ] i18n đủ 22 locale cho tiêu đề màn hình + label từng số liệu.
- [ ] Test: nếu thêm `lifetimeCoinsEarned`, test `GameController` xác nhận
      cộng đúng tổng qua nhiều nguồn (thắng màn + comeback bonus + achievement
      reward cộng dồn đúng, không double-count, không giảm khi tiêu xu mua
      booster/skin — chỉ track "đã kiếm", không phải "đang có").
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- Nếu thấy việc thêm `lifetimeCoinsEarned` + refactor mọi điểm cộng coin quá
  rộng so với SP 3, có thể bỏ qua con số này và chỉ hiển thị 5 metric
  achievement sẵn có — task vẫn đạt được mục tiêu chính (dashboard tổng hợp)
  mà không cần đụng nhiều call site cộng coin. Quyết định cụ thể để lại cho
  người implement dựa theo mức độ rủi ro thực tế lúc đó.
- Đây là màn hình đọc dữ liệu, không có write nào ngoài field mới (nếu chọn
  làm) — rủi ro regression thấp.

DoD chung: `../README.md`.
