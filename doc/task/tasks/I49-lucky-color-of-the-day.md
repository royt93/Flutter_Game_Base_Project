# I49 — Lucky Color of the Day

**Epic:** Meta/retention · **SP:** 3 · **Pri:** Could · **Deps:** không

## Mục tiêu

Mỗi ngày (theo epoch-day), hệ thống chọn ngẫu nhiên (seed theo ngày, giống
daily spin) 1 trong các màu gem hiện có làm "màu may mắn". Trong campaign,
mỗi khi người chơi pop 1 nhóm mà màu của nhóm đó trùng màu may mắn hôm
nay, điểm nhóm đó được nhân hệ số 1.2 (làm tròn). Hiển thị 1 badge nhỏ ở
`game_screen.dart` (góc HUD) cho biết màu may mắn hôm nay.

## Vì sao

Cơ chế nhỏ, chi phí thấp, tạo lý do quay lại mỗi ngày để "xem màu may mắn
hôm nay là gì" — bổ sung cho I48 (Login Streak) và Daily Spin (I6) theo
hướng retention nhưng khác cơ chế (không phải chuỗi ngày, không phải quay
số một lần) mà là 1 modifier áp toàn ngày lên gameplay chính (campaign),
tái dùng chính xác pattern `Random(_todayEpochDay())` đã dùng cho daily
spin.

## Acceptance criteria

- [ ] Hàm pure `int luckyColorIndexForDay(int epochDay, int colorCount)`
  trong `lib/data/` — dùng `Random(epochDay)` seed cố định, trả về 1
  index màu trong khoảng `[0, colorCount)`. Deterministic: cùng
  `epochDay`+`colorCount` luôn ra cùng kết quả.
- [ ] `GameController` gọi hàm này với `_todayEpochDay()` và
  `currentLevel.colorCount` mỗi khi bắt đầu 1 level campaign — lưu vào 1
  `RxInt luckyColorIndex` (không cần persist, tính lại mỗi lần vì hàm
  deterministic theo ngày).
- [ ] Trong `PopStarGame._tryPop`/tính điểm: nếu màu nhóm vừa pop ==
  `controller.luckyColorIndex.value` VÀ đang ở `GameMode.campaign`, nhân
  điểm nhóm đó ×1.2 (làm tròn `round()`) trước khi cộng vào `score`.
  Không áp dụng cho side-mode nào khác (giữ scope tối thiểu, có thể mở
  rộng sau).
- [ ] Badge HUD: 1 chip nhỏ hiển thị màu + icon may mắn, đặt cạnh
  target-score bar hiện có trong `game_screen.dart`, chỉ hiện khi
  `mode == campaign`.
- [ ] Unit test `test/data/lucky_color_test.dart`: deterministic theo
  seed; luôn trong khoảng hợp lệ `[0, colorCount)`; các `colorCount`
  khác nhau (4-7 theo world) đều hoạt động đúng.
- [ ] Unit test tính điểm nhân hệ số (trong `lib/data/levels_test.dart`
  hoặc file test điểm hiện có) — verify `scoreForGroup(n) * 1.2` làm
  tròn đúng với vài giá trị `n` mẫu.
- [ ] i18n cho tooltip/label badge, đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Không cần `StorageKeys` mới — giá trị tính lại mỗi ngày từ
  `_todayEpochDay()`, không cần lưu trạng thái giữa các lần mở app (khác
  I48, vốn cần lưu streak liên tục).
- Vị trí hàm mới: `lib/data/lucky_color.dart` — pure Dart, không phụ
  thuộc Flame/GetX, theo đúng convention `lib/data/`.
- Điểm nhân hệ số áp dụng ở đúng điểm `pop_star_game.dart` đã gọi
  `scoreForGroup(group.length)` — chỉ nhân thêm 1 bước trước khi cộng vào
  `controller.addScore(...)`, không sửa hàm `scoreForGroup` gốc trong
  `lib/data/levels.dart` (giữ hàm đó thuần, không phụ thuộc ngày).

DoD chung: `../README.md`.
