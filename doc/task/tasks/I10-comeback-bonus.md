# I10 — Comeback bonus

**Epic:** Meta/retention · **SP:** 3 · **Pri:** Should · **Deps:** none

## Mục tiêu
Vắng mặt ≥3 ngày (so `lastOpenDate` lưu trong `SharedPreferences`) → lần mở
app kế tiếp tặng gói coin/booster comeback 1 lần.

## Vì sao
Retention rẻ tiền, tái dùng hạ tầng ngày-tháng đã có
(`durationToLocalMidnight`/`claimDaily`), không cần hệ thống mới.

## Acceptance criteria
- [x] Lưu `lastOpenDate` mỗi lần mở app (`main.dart` hoặc `home_screen.initState`).
- [x] Khoảng cách ≥3 ngày kể từ `lastOpenDate` → hiện dialog tặng quà 1 lần, sau
      đó reset mốc.
- [x] Không chồng với daily reward cùng lúc (ưu tiên hiện dialog comeback
      trước; daily reward vẫn claim được sau như thường).
- [x] Unit test: hàm tính "cần comeback bonus" đúng với các mốc ngày khác nhau.

## Rà soát checkbox (2026-07-13)
- Storage key thực tế là `StorageKeys.lastOpenDay` (`lib/core/storage_service.dart`
  dòng 38, cùng nội dung "lưu lần mở app gần nhất" mà task mô tả là `lastOpenDate`).
- `lib/presentation/controllers/game_controller.dart`: `checkComebackBonus()` đọc/ghi
  `lastOpenDay`, dùng hàm thuần `needsComebackBonus` (`lib/core/utils/comeback_bonus.dart`).
- Gọi từ `lib/presentation/screens/home_screen.dart` dòng ~40, hiện dialog riêng
  (không chặn daily reward claim sau đó).
- `test/core/utils/comeback_bonus_test.dart` test nhiều mốc ngày khác nhau.

## Subtasks (gợi ý file)
1. `lib/core/storage_service.dart`: key `lastOpenDate`.
2. `lib/presentation/controllers/game_controller.dart` (hoặc riêng): kiểm tra +
   claim.
3. Dialog UI (`NeonDialog.overlay`).

## Ghi chú kỹ thuật
1 hàm thuần tính điều kiện (dễ test) — phần UI chỉ gọi hàm đó.

DoD chung: `../README.md`.
