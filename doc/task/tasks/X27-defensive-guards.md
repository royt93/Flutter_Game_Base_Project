# X27 — Guard phòng thủ: crate trừ coin trước khi roll, `featuredLevelId` chia 0

**Epic:** E6 Hardening · **SP:** 2 · **Pri:** Could · **Mức:** P2
**Deps:** — · **Liên quan:** [[I63]] [[I38]]
**Trạng thái:** ✅ Done (2026-08-11)

## Vấn đề A — Mystery Crate trừ coin trước khi biết có nhận được gì
`rollMysteryCrate()` (`game_controller.dart:485-565`):

```dart
coins.value -= mysteryCrateCost;          // dòng 536 — trừ 250 coin
StorageService.to.setInt(StorageKeys.coins, coins.value);
final item = rollCrate(eligiblePool: eligiblePool, rng: rng);
if (item == null) return null;            // dòng 541 — mất 250 coin, không nhận gì
```

`eligiblePool.isEmpty` đã được check ở dòng 534, nên nhánh `item == null`
hiện **không** với tới được. Nhưng thứ tự "trừ tiền trước, kiểm tra sau" là
một quả mìn: bất kỳ ai sửa `rollCrate` (thêm điều kiện lọc, đổi trọng số) đều
có thể mở nó ra mà không nhận ra.

## Vấn đề B — `featuredLevelId` chia cho `unlockedLevel` không guard
`game_controller.dart:1856-1860`:

```dart
return currentWeekIndex % unlockedLevel.value + 1;
```

`unlockedLevel` load với `def: 1` nên bình thường ≥1. Nhưng nếu key tồn tại
với giá trị `0` (save hỏng, import backup giả mạo — xem [[X26]], hoặc
downgrade version), `def` không cứu được và đây là **modulo cho 0** →
`IntegerDivisionByZeroException`.

Hàm này được gọi từ `startWeeklyFeatured()` và từ UI (home screen hiện tên
level tuần) → crash ở màn Home.

## Vì sao Could
Cả hai đều là *chưa* xảy ra được với code hiện tại. Không phải bug đang gây
hại. Nhưng cả hai đều là 1 dòng để sửa và cả hai đều nằm trên đường mà
[[X18]]/[[X26]] đã chứng minh là có thật (dữ liệu hỏng đi vào từ backup).

Xếp Could một cách có chủ ý: **không** kéo task này lên trước bất kỳ P1 nào.
Nếu sprint hết chỗ, bỏ nó — đó là lý do nó là Could.

## Acceptance criteria
- [x] `rollMysteryCrate` chỉ trừ coin **sau khi** `rollCrate` trả về item
      không null. Roll thất bại → coin không đổi, trả `null`.
- [x] `featuredLevelId` không ném exception khi `unlockedLevel.value <= 0`;
      trả về `1`.
- [x] `_load()` kẹp `unlockedLevel` về `max(1, stored)` — **root cause fix**,
      mọi consumer khác cũng an toàn, không chỉ hàm này.
- [x] Test: `unlockedLevel = 0` trong storage → app boot, `featuredLevelId`
      trả giá trị hợp lệ, `startWeeklyFeatured()` không ném.

## Đã sửa
1. `rollMysteryCrate` — đảo thứ tự: roll trước, trừ coin sau.
2. `_load()` — `unlockedLevel.value = max(1, getInt(...))`. Ghi rõ trong
   comment vì sao `def: 1` **không** đủ: `def` chỉ áp dụng khi key vắng mặt,
   còn save hỏng/backup giả mạo lưu thẳng giá trị `0` thì `def` không cứu.
3. `featuredLevelId` — guard `unlocked < 1` làm lớp phòng thủ thứ hai.
4. Test trong `test/game/booster_noop_test.dart`, nhóm X27.

## Rà thêm (theo Ghi chú)
Grep `%`/`~/` trong `lib/` với toán hạng đọc từ storage: không còn chỗ nào
khác chia cho giá trị không được kẹp. Các phép chia còn lại đều dùng hằng số
(`86400000`, `7`, `seasonLengthDays`) hoặc `.length` của bảng const.

DoD chung: `../README.md`.
