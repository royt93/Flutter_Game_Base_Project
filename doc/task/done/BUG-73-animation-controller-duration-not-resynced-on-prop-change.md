---
id: BUG-73
title: "3 widget (WheelSpinner/HoldToConfirmButton/ShimmerPlaceholder) không resync AnimationController.duration khi prop đổi"
type: bug
priority: P3
effort: M
source: "claude (fork audit round 2, độc lập) — cùng loại bug đã sửa ở BUG-30/BUG-70"
---

## Vị trí
- `lib/presentation/widgets/common/wheel_spinner.dart:119-122` (khởi tạo
  `_controller = AnimationController(vsync: this, duration:
  widget.spinDuration)`), `didUpdateWidget` (dòng ~151-163) có resync
  listener khi `controller` đổi nhưng KHÔNG update `_controller.duration`
  khi `widget.spinDuration` đổi.
- `lib/presentation/widgets/common/hold_to_confirm_button.dart:80-83`
  (`duration: widget.duration`) — class này KHÔNG có override
  `didUpdateWidget` nào cả.
- `lib/presentation/widgets/common/shimmer_placeholder.dart:49-52`
  (`duration: widget.duration`) — cũng KHÔNG có `didUpdateWidget`.

## Hiện trạng
Cả 3 file đều tạo `AnimationController` với `duration:` đọc từ 1 prop của
widget ngay lúc `initState()`, nhưng không có cơ chế nào cập nhật lại
`_controller.duration` khi đúng prop đó (`spinDuration`/`duration`) đổi
giữa 2 lần rebuild cùng 1 instance widget (cùng `key`).

So sánh: `countdown_chip.dart` (đã sửa ở BUG-30) và `screen_shake.dart`
trong CÙNG thư mục đã có `didUpdateWidget` đúng pattern resync khi prop đổi
— 3 file trên là phần còn sót lại chưa theo đúng convention đã thiết lập.

## Vì sao cần / Hậu quả
Nếu app cha đổi `spinDuration`/`duration` trên 1 widget đang mounted (ví dụ
setting "chơi chậm hơn cho người mới", hoặc 1 accessibility option "giữ nút
lâu hơn" cho `HoldToConfirmButton`), animation/hold-gate vẫn chạy ở
DURATION CŨ mãi mãi — thay đổi im lặng không có tác dụng, không lỗi không
log. Với `HoldToConfirmButton` cụ thể, đây là 1 safety gate (xác nhận hành
động nguy hiểm bằng cách giữ nút đủ lâu) — không cập nhật đúng duration có
thể ảnh hưởng tới đúng ý đồ UX an toàn của nó.

## Đề xuất
Thêm `didUpdateWidget` cho cả 3 file, đúng pattern đã có sẵn ở
`countdown_chip.dart`/`screen_shake.dart`: so sánh
`oldWidget.spinDuration/duration != widget.spinDuration/duration`, nếu khác
thì `_controller.duration = widget.spinDuration/duration;` (không cần huỷ
tạo lại controller, `AnimationController.duration` là setter cho phép gán
lại trực tiếp).

## Acceptance criteria
- [x] Cả 3 widget: đổi prop duration liên quan giữa 2 lần
      `tester.pumpWidget` (cùng key) → `_controller.duration` (hoặc hành vi
      animation quan sát được) phản ánh đúng giá trị MỚI.
- [x] Không đổi duration → hành vi giữ nguyên như cũ (case phổ biến nhất
      không được phá).
- [x] Có test cho cả 3 file, mỗi file ít nhất 1 test case mới.
- [x] Không phá bất kỳ test hiện có nào của 3 file này.

## Quyết định

**Phát hiện thêm quan trọng khi implement (không có trong đề xuất ban đầu
của task)**: đọc trực tiếp Flutter framework source
(`animation_controller.dart`) phát hiện `WheelSpinner`/`HoldToConfirmButton`
và `ShimmerPlaceholder` KHÔNG cùng 1 loại fix đơn giản như đề xuất ban đầu:

- `WheelSpinner`/`HoldToConfirmButton` dùng `_controller.forward(from: 0)`
  MỖI LẦN trigger (spin/hold mới) — `_animateToInternal` đọc `this.duration`
  TƯƠI ngay lúc gọi, nên chỉ cần set `_controller.duration =
  widget.X;` trong `didUpdateWidget` TRƯỚC lần trigger tiếp theo là đủ.
- `ShimmerPlaceholder` dùng `_controller.repeat()` gọi ĐÚNG 1 LẦN (trong
  `didChangeDependencies`, chạy liên tục vô hạn) — `repeat()`'s `period`
  được CHỐT 1 LẦN vào 1 `_RepeatingSimulation` nội bộ ngay lúc gọi, và
  KHÔNG đọc lại `duration` mỗi vòng lặp. Chỉ set `_controller.duration =
  widget.duration;` (đúng y hệt cách làm ở 2 widget kia) sẽ KHÔNG có tác
  dụng gì lên vòng lặp đang chạy — phải gọi lại `_controller.repeat()` để
  restart loop với period mới thì mới thật sự lấy hiệu lực.

**Implementation**:
- `wheel_spinner.dart`: thêm vào `didUpdateWidget` (đã có sẵn override):
  `if (oldWidget.spinDuration != widget.spinDuration) { _controller.duration
  = widget.spinDuration; }`.
- `hold_to_confirm_button.dart`: thêm HẲN 1 `didUpdateWidget` override mới
  (trước đó không có), cùng pattern.
- `shimmer_placeholder.dart`: thêm `didUpdateWidget` mới, set `.duration`
  RỒI gọi lại `_controller.repeat()` (chỉ khi
  `!NeonTheme.reducedMotion(context)`, đúng điều kiện gốc `didChangeDependencies`
  đã dùng để quyết định có chạy animation hay không).

**TDD**: viết test trước cho cả 3 file (mỗi file thêm 1-2 test case behavioral,
KHÔNG cần lộ private state — `WheelSpinner`/`HoldToConfirmButton` verify qua
timing thật của callback `onSpinEnd`/`onConfirm`; `ShimmerPlaceholder` verify
qua đọc ngược `t` từ `LinearGradient.begin.x` render thật, tái dùng
`_decorationOf` helper có sẵn trong file test) → `git stash` riêng 3 file
lib → chạy cả 3 test mới: FAIL đúng dự đoán ở cả 3 file (wheel_spinner:
`onSpinEnd` chưa fire sau 150ms vì vẫn kẹt duration 5s cũ; hold_to_confirm:
tương tự `count` vẫn 0; shimmer: `t` đo được ~0.005 thay vì ~0.5 vì loop vẫn
chạy period 10s cũ) → khôi phục, chạy lại — tất cả pass.

**Kết quả**:
- `flutter analyze` (root + `example/`): sạch (phải sửa 1 lint nhỏ tự phát
  sinh trong lúc viết test — `no_leading_underscores_for_local_identifiers`
  + `unnecessary_non_null_assertion` — đã sửa).
- `dart run tool/api_compatibility.dart check`: `unchanged`.
- `flutter test --exclude-tags slow` (root): 2354 test, 19 fail — đúng
  khớp 19 golden-image baseline đã biết, KHÔNG có flaky phát sinh, không có
  regression.
- `example/`: `flutter analyze` sạch, `flutter test --exclude-tags slow`:
  149/149 pass (3 widget này đều được dùng thật trong `WidgetShowcaseScreen`
  — xác nhận fix không phá demo có sẵn).
- Không cần smoke test device (task cho phép bỏ qua — widget test timing
  thật đã đủ chứng minh cả 3 case).

**Tự chấm điểm: 9.5/10.** Fix đúng root cause cho cả 3 file, và quan trọng
hơn — TỰ PHÁT HIỆN được sự khác biệt nội tại giữa "controller trigger theo
sự kiện rời rạc" (forward per-trigger) vs "controller chạy loop liên tục"
(repeat một lần) mà đề xuất gốc trong task KHÔNG hề phân biệt — nếu áp dụng
y hệt fix của 2 file kia cho `shimmer_placeholder.dart` sẽ tạo ra 1 fix
TRÔNG như đúng (compile sạch, code "hợp lý") nhưng KHÔNG có tác dụng thật
sự nào, và chỉ bị phát hiện nếu ai đó test kỹ bằng timing thật như task này
đã làm. Trừ 0.5 vì việc phát hiện sâu này tốn thêm thời gian đọc trực tiếp
Flutter SDK source đáng lẽ có thể được ước tính effort cao hơn `M` ngay từ
đầu task.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-73-animation-controller-duration-not-resynced-on-prop-change.md`
này trước khi làm. Đọc TOÀN BỘ `lib/presentation/widgets/common/countdown_chip.dart`
VÀ `lib/presentation/widgets/common/screen_shake.dart` để lấy đúng pattern
`didUpdateWidget` mẫu, rồi đọc kỹ cả 3 file cần sửa
(`wheel_spinner.dart`/`hold_to_confirm_button.dart`/`shimmer_placeholder.dart`)
trước khi sửa — chú ý `wheel_spinner.dart` đã CÓ `didUpdateWidget` (chỉ
thiếu phần duration), còn 2 file kia hoàn toàn CHƯA có override này (cẩn
thận không phá logic khác nếu widget có state phức tạp hơn xung quanh
`initState`). Implement bằng TDD — viết test trước, xác nhận fail trên code
cũ, rồi mới sửa. Có thể làm từng file 1, hoặc gộp cả 3 vào 1 commit nếu fix
đơn giản và đồng dạng — tự quyết định dựa trên độ phức tạp thực tế sau khi
đọc code.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria (cả 3 file).
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (widget test đủ chứng minh).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ
test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các
checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ
`doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]`
khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — fork audit đã trích dẫn chính xác file:line cho cả 3 file, xác nhận
qua grep rằng đây là 3 file DUY NHẤT trong `lib/presentation/widgets/` có
pattern `AnimationController(duration: widget.X)`, và xác nhận
`test/widget/common/{wheel_spinner,hold_to_confirm_button,shimmer_placeholder}_test.dart`
chưa có test nào rebuild widget với duration prop đổi. Có tiền lệ sửa đúng
loại bug này 2 lần trong cùng repo (BUG-30, BUG-70), xác nhận đây là
convention đã thiết lập rõ mà 3 file này bị sót. Không trùng task nào
trong `doc/task/done/`.
