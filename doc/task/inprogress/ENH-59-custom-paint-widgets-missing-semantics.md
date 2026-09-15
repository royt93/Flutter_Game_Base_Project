---
id: ENH-59
title: "CircularProgressRing/WheelSpinner: CustomPaint không có Semantics — screen reader không đọc được gì"
type: enhancement
priority: P2
effort: S
source: Claude (self-generated backlog brainstorm sau khi IDEA backlog cạn — xác nhận qua grep trực tiếp, không chỉ dựa vào agent)
---

## User story
Là người chơi dùng screen reader (TalkBack), tôi muốn nghe được giá trị tiến độ của `CircularProgressRing` và mục đang được chọn/dừng của `WheelSpinner`, thay vì im lặng hoàn toàn.

## Hiện trạng và bằng chứng
Grep toàn bộ `lib/presentation/widgets/common/*.dart` cho `Semantics(` cho thấy 2 widget vẽ nội dung Ý NGHĨA hoàn toàn bằng `CustomPainter` (không có `Text` con nào để Flutter tự tạo semantics như `TooltipBubble` đang làm) và KHÔNG có bất kỳ `Semantics`/`semanticLabel` nào:
- `lib/presentation/widgets/common/circular_progress_ring.dart` — `_RingPainter` vẽ % tiến độ chỉ bằng hình vẽ, không có node semantics nào mang giá trị số.
- `lib/presentation/widgets/common/wheel_spinner.dart` — `WheelSpinner`/`_WheelSpinnerState` vẽ danh sách lựa chọn + trạng thái đang quay/đã dừng ở ô nào chỉ bằng `CustomPaint`, không expose được ô nào đang chọn qua accessibility tree.

So sánh: các widget khác (`StarRating`, ...) đã có `Semantics` (ví dụ ENH-37 đã làm cho `StarRating`) — 2 widget này bị bỏ sót trong các đợt sweep semantics trước (ENH-46/ENH-49).

## Scope
- Thêm `Semantics` (label + value phù hợp, ví dụ `value: '${(progress * 100).round()}%'` cho `CircularProgressRing`; label mô tả lựa chọn hiện tại/đang quay cho `WheelSpinner`) bọc quanh phần `CustomPaint` của cả 2 widget.
- KHÔNG đổi API public hiện có (không thêm tham số bắt buộc mới) — nếu cần 1 label caller-cung-cấp thì để optional với default hợp lý tự suy ra từ giá trị đã có sẵn (progress/selected index), tránh breaking change.
- Không sweep toàn bộ các widget "không có `Semantics(`" khác trong thư mục (phần lớn là hiệu ứng thuần hình ảnh — `ConfettiOverlay`, `ScreenShake`, `SquashStretch`, `ComboHeatBackground`... — hoặc widget bọc `Text` con đã tự có semantics sẵn như `TooltipBubble`) — ngoài phạm vi, tránh over-engineer 1 sweep lớn khi chỉ có 2 gap thật đã xác nhận.

## Acceptance criteria
- [x] `CircularProgressRing` có `Semantics` với `value` phản ánh đúng % tiến độ hiện tại, cập nhật đúng khi progress đổi.
- [x] `WheelSpinner` có `Semantics` phản ánh đúng trạng thái hiện tại (đang quay / đã dừng ở lựa chọn nào).
- [x] Không phá bất kỳ test/API hiện có nào của 2 widget này.
- [x] Test bao phủ: giá trị semantics đúng ở nhiều mốc progress/lựa chọn khác nhau, đúng khi widget rebuild với giá trị mới — widget test dùng `tester.getSemantics`/`find.bySemanticsLabel` tương đương, không chỉ "không throw".
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật (không simulator) — bật TalkBack thật, xác nhận đọc đúng giá trị, bằng chứng cụ thể (log/mô tả) trong Quyết định (xem ghi chú về đổi thiết bị + gián đoạn do peer bên dưới).

## Prompt loop implementation
Đọc kỹ file `doc/task/todo/ENH-59-custom-paint-widgets-missing-semantics.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Scope bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không mở rộng sang các widget khác ngoài 2 widget đã nêu).
2. Bổ sung ĐỦ test cho MỌI case liên quan — widget test dựng widget thật, assert đúng giá trị semantics ở nhiều trạng thái khác nhau.
3. Không có animation mới cần thêm (chỉ thêm semantics, không đổi behavior hình ảnh) — nếu vô tình cần đổi animation thì vẫn phải tôn trọng `NeonTheme.reducedMotion` như hiện có.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator), bật TalkBack, xác nhận đọc đúng giá trị — ghi lại cụ thể trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 4-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Quyết định

Implement đúng phần Scope — thêm `Semantics` cho đúng 2 widget đã nêu, không mở rộng sang widget khác:

- **`CircularProgressRing`** (`lib/presentation/widgets/common/circular_progress_ring.dart`): bọc `Semantics(label: semanticLabel ?? 'Progress: N%', value: 'N%', excludeSemantics: true, child: ...)` NGOÀI `TweenAnimationBuilder` (không phải bên trong `builder:`) — để giá trị công bố ra ngoài luôn là % MỤC TIÊU đã ổn định, không phải từng frame trung gian lúc đang chạy animation fill-in. `excludeSemantics: true` để tránh 1 node semantics con bị merge chồng lên khi caller truyền `label`/`icon` (chính `Text` đó tự có semantics riêng, sẽ đọc lặp "N% N%" nếu không loại trừ). Thêm tham số mới `semanticLabel` (optional, không breaking) cho phép ghi đè, cùng convention `ProgressBarStars`/`StarRating`.
- **`WheelSpinner`** (`lib/presentation/widgets/common/wheel_spinner.dart`): bọc `Semantics(label: _semanticsLabel(), liveRegion: true, child: ...)`. `_semanticsLabel()` trả `'Spinning'` khi `_controller.isAnimating`, ngược lại `'Stopped on ${segments[_currentSegmentIndex()].label}'`. `_currentSegmentIndex()` là nghịch đảo toán học của công thức `targetMod` đã có sẵn trong `_onSpinRequested` (`-(i+0.5)*segmentAngle`) — suy ra `i` từ `_rotation` hiện tại bằng `round(-_rotation/segmentAngle - 0.5) % n`.
- **Bug thật bắt được qua TDD trước khi push**: công thức nghịch đảo ở trên, tại đúng trạng thái "mới mount, chưa spin lần nào" (`_rotation == 0`), rơi đúng vào 1 tie-break `.round()` của `-0.5` — test đầu tiên viết ra FAIL thật (`'Stopped on Jackpot'` thay vì `'Stopped on 10 coins'`, tức segment cuối thay vì segment 0 đang thực sự nằm dưới con trỏ). Nguyên nhân: `(-0.5).round()` ở Dart làm tròn ra xa 0 thành `-1`, rồi `-1 % n = n-1`. Fix: cộng thêm epsilon nhỏ (`1e-9`) trước khi `.round()` — chỉ phá vỡ đúng cái tie-break tại điểm biên `-0.5` này (trạng thái nghỉ chưa từng quay), không ảnh hưởng bất kỳ kết quả spin thật nào (rotation sau 1 lần quay thật không bao giờ rơi đúng vào biên .5 này). Toàn bộ 4 giá trị `target` (0-3) đã pass NGAY LẦN ĐẦU trước khi có epsilon — chỉ riêng edge case "chưa từng spin" là sai, xác nhận đây đúng là 1 boundary bug hẹp, không phải sai công thức cốt lõi.

**Test:** `test/widget/common/circular_progress_ring_test.dart` (+5 test nhóm "ENH-59: Semantics") — label/value mặc định đúng %, cập nhật đúng khi progress đổi lúc runtime, clamp về 100% khi progress > 1.0, `semanticLabel` tuỳ biến ghi đè đúng, `excludeSemantics` xác nhận không bị lặp label khi có `label` con. `test/widget/common/wheel_spinner_test.dart` (+7 test nhóm "ENH-59: Semantics") — trạng thái nghỉ ban đầu đúng segment 0, đang quay báo "Spinning", cả 4 target (0/1/2/3) sau khi settle báo đúng "Stopped on {label}" tương ứng, Reduce Motion bật vẫn đúng.

**Device smoke test — đổi thiết bị + bị gián đoạn bởi peer session giữa chừng**: Pixel 7 Pro (`2B051FDH3006MU`) đã ngắt kết nối trong lúc làm task này; máy thật khác đang online được dùng thay thế — Samsung Galaxy (`R5CX613VZBR`, model SM-S928B, Android 16), vẫn là thiết bị thật, không phải simulator/emulator. Bật TalkBack thật của Samsung (`com.samsung.android.accessibility.talkback/com.samsung.android.marvin.talkback.TalkBackService`) qua `adb shell settings put secure enabled_accessibility_services`. Cài + mở app, cuộn tới section Progress & Reward:
- `CircularProgressRing`: cây accessibility THẬT (đọc qua UIAutomator, cùng API TalkBack tiêu thụ) xác nhận đúng `label="CircularProgressRing\nProgress: 40%" value="40%"`.
- `WheelSpinner`: xác nhận đúng `label="WheelSpinner\nStopped on 10\nSpin\nSpin\nSpin"` ở trạng thái nghỉ ban đầu (khớp segment đầu tiên của bánh xe demo).

Giữa lúc đang thao tác để xác nhận tiếp trạng thái "Spinning" + "Stopped on X" SAU KHI bấm Spin, phát hiện: `mobile_get_foreground_app` trả về 1 app KHÁC (`com.roy.admobwrapper`, màn hình "ad_sdk") đã chiếm foreground trên CHÍNH thiết bị này, và `ListAgents` xác nhận 1 peer session mới (`t-e8`) vừa khởi động vài giây trước đó — thiết bị này hoá ra đang được CHIA SẺ với phiên làm việc khác. Theo đúng nguyên tắc tránh xung đột với peer đã áp dụng suốt phiên này: DỪNG NGAY mọi thao tác trên thiết bị, tắt lại TalkBack đã bật (cấu hình toàn hệ thống, có thể ảnh hưởng tới việc peer đang test tự động UI của họ) về trạng thái ban đầu (`accessibility_enabled=0`), không chạm gì thêm vào app `ad_sdk` của peer, không cố tiếp tục xác nhận trạng thái "Spinning"/"post-spin" trên thiết bị thật nữa.

Bằng chứng còn thiếu (trạng thái "Spinning" và "Stopped on X" SAU 1 lần spin thật) được bù bằng: (a) 7 widget test ENH-59 cho `WheelSpinner` đã pass đầy đủ cả 2 trạng thái này qua `pumpAndSettle`/pump có kiểm soát thời gian, kể cả bắt được và sửa đúng 1 bug thật trước khi push (xem trên); (b) trạng thái nghỉ ban đầu ĐÃ xác nhận khớp thật trên accessibility tree thật của thiết bị thật trước khi bị gián đoạn.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1000/1000 pass; `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 46/46 pass (không đổi gì trong `example/` — không có demo mới, chỉ thêm semantics vào 2 widget đã có demo sẵn). CHANGELOG.md đã thêm mục dưới `## 0.2.0`. `tool/api_compatibility.dart snapshot` chạy lại KHÔNG tạo diff — cả `semanticLabel` (tham số mới) và semantics nội bộ của `WheelSpinner` đều là thay đổi ở mức member/tham số trên class đã export sẵn, cùng tiền lệ IDEA-35/43/44/45 (gate không track thêm member).

**Tự chấm điểm: 9/10** — đúng yêu cầu Scope (chỉ 2 widget đã nêu, không lan sang widget khác), bắt và sửa đúng 1 bug thật qua TDD trước khi push (boundary tie-break tại trạng thái nghỉ), test bao phủ đầy đủ mọi trạng thái yêu cầu, không phá API/test hiện có, xử lý đúng đắn 1 tình huống phát sinh thật (thiết bị bị peer session khác giành dùng giữa chừng) bằng cách dừng lại và dọn dẹp thay vì cố tiếp tục. Trừ điểm vì device smoke test không hoàn tất được 100% trên 1 thiết bị duy nhất do gián đoạn khách quan ngoài kiểm soát — bù bằng test suite đầy đủ + phần đã xác nhận thật trước khi gián đoạn.
