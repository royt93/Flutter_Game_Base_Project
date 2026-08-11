# T2 — 5 controller không có test nào

**Epic:** E7 Test coverage · **SP:** 8 · **Pri:** Must · **Deps:** —
**Trạng thái:** ✅ Done (2026-08-11)

## Vấn đề
Repo có 118 file test cho 129 file source — độ phủ nhìn chung tốt. Nhưng
đúng 5 controller, tức toàn bộ lớp orchestration của các mode phụ, không có
test nào:

| File | Dòng | Trách nhiệm | Test hiện có |
|---|---|---|---|
| `game_screen_controller.dart` | 534 | drive toàn bộ màn chơi, FTUE, booster arm, win/lose | ❌ |
| `home_screen_controller.dart` | — | build carousel, coach-mark shop | ❌ |
| `pass_and_play_controller.dart` | — | 1 ván hot-seat 2 người | ❌ |
| `treasure_map_controller.dart` | — | 5 stage expedition | ❌ |
| `raid_boss_controller.dart` | — | cửa sổ cuối tuần, bậc thưởng damage | ❌ |

`boss_rush_controller.dart` **có** test (`test/presentation/boss_rush_controller_test.dart`)
— dùng nó làm khuôn, 4 controller còn lại theo đúng pattern đó
(`ever(gameCtrl.ended, …)`, `Get.put` trong screen, xoá khi rời).

## Vì sao Must
Lớp này chứa logic khó nhất để suy luận bằng mắt: **kết thúc màn là bất đồng
bộ** (phát qua `gameCtrl.ended` sau khi animation Flame xong), state sống
xuyên nhiều màn hình, và mỗi controller quản một vòng đời riêng. Đúng loại
code mà bug hồi quy trốn được.

`raid_boss_controller` còn giữ vị từ cửa sổ cuối tuần (`isRaidActiveForEpochDay`,
Fri–Sun) — đây là logic phụ thuộc thời gian, và CLAUDE.md nói rõ test loại
này **phải inject epoch day**, không đọc đồng hồ. Không có test nghĩa là quy
tắc đó chưa được thực thi ở đâu cả.

## User story
*As a* dev sửa một mode phụ *I want* test bắt được hồi quy vòng đời *so that*
tôi không phải chơi tay 5 mode sau mỗi lần refactor.

## Acceptance criteria
- [x] Mỗi controller có 1 file `test/presentation/<tên>_test.dart`.
- [x] `raid_boss_controller_test.dart` (18 case): cửa sổ Fri–Sun qua **epoch
      day inject**, giới hạn lượt/ngày, bậc thưởng damage, reset theo tuần.
      **Không** `DateTime.now()` trong test.
- [x] `treasure_map_controller_test.dart` (13 case): tiến 5 stage, modifier
      đúng từng stage, `consumeTreasureMap()` trừ đúng 1 và chặn khi hết,
      `completeTreasureMap()` mở board frame.
- [x] `pass_and_play_controller_test.dart` (12 case): bàn gốc không bị mutate
      giữa 2 lượt, phân định thắng/thua/hoà.
- [x] `game_screen_controller_test.dart` (26 case): `GameUi` chuyển qua
      `ever(ended)`, FTUE chỉ lần đầu ở campaign level 1, coach-mark booster
      không chồng FTUE, `again`/`next` dọn state.
- [x] `home_screen_controller_test.dart` (12 case): `buildHomeCards` phản ánh
      state đã đổi ở màn khác sau resume.
- [x] Không dùng device thật.
- [x] `flutter test --exclude-tags slow` xanh: **882 pass** (trước T2: 801).

## Đã làm
**81 test mới**, 5 file. Không sửa một dòng production nào — subtask 3 dự
phòng "nếu khó test thì ghi lại chỗ vướng" không phải dùng tới.

### Inject thời gian mà không đổi production
AC bắt Raid Boss test qua epoch day inject, nhưng controller không có tham số
override. Thay vì thêm API chỉ để phục vụ test, tái dùng **điểm inject đã có
sẵn**: `todayEpochDayClamped()` (X22) trả `max(ngày thật, maxEpochDaySeen)`,
nên gieo `maxEpochDaySeen` là ép được ngày, và test đi đúng code path thật.

Ràng buộc kèm theo: ngày gieo phải > ngày thật (lớp kẹp không lùi), nên mọi
mốc trong test nằm ở tương lai xa (`epochDay 30003` = thứ Sáu). Đã ghi rõ
trong doc đầu file test.

### `GameScreenController` — `testWidgets`, không phải `test`
Bắt buộc, vì: `quit()` gọi `Get.back()` (cần navigator), `_onEndChanged` có
`Future.delayed(350ms)`, và Time Attack/Combo Rush chạy `Timer.periodic`.
Test dựng `GetMaterialApp` thật rồi pump qua từng mốc.

Có 1 case khẳng định **overlay chỉ hiện SAU 350ms** — kiểm luôn rằng độ trễ
tồn tại, không chỉ kiểm kết quả cuối.

## Kiểm chứng (chống test rỗng)
26/26 case của `GameScreenController` xanh ngay lần chạy đầu — đáng ngờ, nên
mutation-check 3 hành vi chính, mỗi cái làm **1 test đỏ**:

| Gỡ khỏi production | Kết quả |
|---|---|
| `if (mode == passAndPlay) return;` trong `_onEndChanged` | đỏ |
| `!ftue &&` trong điều kiện `showBoosterTutorial` | đỏ |
| `armed.value = BoosterMode.none;` trong `again()` | đỏ |

## Ngoài AC
Thêm các nhánh guard mà AC không nêu nhưng không ai kiểm: `beginPlayer2()` khi
chưa `awaitingHandoff`, `nextStage()` khi chưa thắng, `dismiss*` gọi 2 lần,
`consumeAttempt()` quá số lượt, claim thưởng raid 2 lần, và "ended ở mode khác
không đụng state" cho cả treasure map lẫn pass-and-play (bảo vệ đúng dòng
`if (mode != …) return` ở đầu mỗi `_onEnded`).

## Ghi chú kỹ thuật
`GameController` là `permanent: true` và nhiều test dùng `Get.reset()` để
teardown — nhớ rằng `Get.reset()` **không** gọi `onClose()` (đã ghi lại ở
`game_controller.dart:983-992`). Nếu controller nào tạo `Timer`, test sẽ báo
leak frame callback. Đó là tín hiệu bug thật, đừng tắt nó đi.

DoD chung: `../README.md`.
