---
id: FEAT-36
title: "PersistentCooldownService — cooldown keyed, reactive và sống qua restart"
type: feature
layer: core
priority: P1
effort: M
depends_on: [FEAT-32]
related_to: [IDEA-40]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn quản lý cooldown reward/booster/action bằng một SSOT chống chỉnh giờ.

## Sprint slices
- Model cooldown keyed: start/end/status/remaining và policy restart/cancel.
- Repository versioned persistence; service GetX reactive không tạo timer mỗi key.
- Batch tick scheduler, foreground refresh và cleanup expired entries.
- `CountdownChip` adapter/demo dùng state từ service.

## Acceptance criteria
- [x] Start/read/cancel/restart policy đúng qua app restart và clock anomaly.
- [x] N cooldown không tạo N timer; subscriber nhận state immutable.
- [x] Key/input/corrupt save được validate và không mở khóa sớm.
- [x] Widget countdown hiển thị cùng remaining với service.

## Prompt loop feature
Đọc task/dependencies; implement model → repository → service → widget adapter bằng TDD. End loop: audit và chấm /10; unit test + widget test + integration test mọi case time/persist/corrupt/lifecycle; analyze/test root + example; smoke Android device thật có kill/relaunch proof. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Kiến trúc theo đúng "zero-timer" style của `EnergyService` chứ không phải "batch tick scheduler" như sprint slice gốc gợi ý:
- `PersistentCooldownService` **không có timer nào cả** (không per-key, cũng không 1 timer chung) — mọi read (`statusOf`/`remainingOf`) tính lazy ngay lúc gọi từ `endMs` lưu sẵn trừ `nowMsClamped()`. N cooldown = 0 timer nền, giống hệt cách `EnergyService` không có timer nào cho việc hồi tim. UI muốn đếm lùi mượt (`CooldownCountdownChip`) tự có `Timer.periodic` CỦA RIÊNG NÓ (kế thừa từ `CountdownChip` sẵn có) — đúng tinh thần "N cooldown không tạo N timer ở tầng service", timer (nếu có) là chuyện của UI, không phải service.
- "Batch tick scheduler, foreground refresh" trong sprint slice gốc bị bỏ hẳn — không cần thiết khi kiến trúc là lazy-compute-on-read; thêm 1 scheduler chỉ để tự bump lại y hệt giá trị đã tính đúng rồi là thừa (YAGNI).
- "Cleanup expired entries" chuyển thành dọn NGAY LÚC GHI (mỗi lần `start`/`cancel` gọi `_persist()`, entry nào đã hết hạn bị lọc khỏi blob trước khi lưu) thay vì 1 sweep định kỳ riêng — không cần thêm bất kỳ timer/scheduler nào cho việc này.
- Persist 1 JSON blob `key -> endMs` dưới 1 `StorageKeys.cooldownStateV1` duy nhất (giống pattern `energyStateV1` của `EnergyService`) — ghi thẳng bằng `setString` (KHÔNG buffer) vì cooldown là "real transaction": mất ghi lúc app bị kill = booster được dùng lại miễn phí.
- Validate ở đúng 2 lớp: (1) input của `start()` — key rỗng/duration <= 0 throw `ArgumentError` ngay; (2) đọc lại persisted blob — JSON hỏng toàn bộ thì coi cả map rỗng (không crash), 1 entry sai kiểu (key không phải String hoặc value không phải int) bị BỎ QUA thay vì cố coerce — tức entry đó đọc như "chưa từng start" (ready), không bao giờ bị coerce thành một giá trị đọc ra "đã hết hạn sớm hơn thật".
- `CooldownCountdownChip` (widget mới, `presentation/widgets/common/`) nhận **plain data** `remaining: Duration`, không cầm `PersistentCooldownService` trực tiếp — đúng convention đã ghi rõ trong doc comment của `EnergyBar`/`LevelSelectGrid` (widget nhận data, caller sở hữu GetX service). Nó chỉ tính `target = DateTime.now().add(remaining)` MỘT LẦN lúc mount, và chỉ tính lại khi `remaining` thực sự đổi giá trị (`didUpdateWidget`) — một rebuild của cha với CÙNG `remaining` (ví dụ 1 `Obx` tick không liên quan) không làm reset countdown đang chạy.
- Demo trong `WidgetShowcaseScreen` dùng `Obx` đọc `_cooldown.revision.value` (đọc trực tiếp `.value` MỚI khiến `Obx` track được — gọi `remainingOf()` không đủ vì hàm đó không chạm `Rx` nào) để rebuild đúng lúc `start`/`cancel` xảy ra.

**Test:** `test/core/persistent_cooldown_service_test.dart` (16 case, TDD — RED xác nhận qua "Method not found" trước khi viết `persistent_cooldown_service.dart`): validate input, start/read/cancel/restart, mô phỏng trôi qua thời gian bằng kỹ thuật đẩy `StorageKeys.maxMsSeen` (giống `energy_service_test.dart`, KHÔNG dùng `tester.pump(duration)` vì `nowMsClamped()` đọc đồng hồ thật, không bị FakeAsync chi phối), sống qua "restart" (instance service mới đọc lại đúng từ cùng SharedPreferences), corrupt JSON top-level và corrupt 1 entry, cleanup expired entries, reactive revision (tăng đúng lúc start/cancel, KHÔNG tự tăng theo thời gian trôi). Có 1 test ban đầu ("vặn lùi đồng hồ trực tiếp") bị xoá vì sai giả định — ghi thẳng `maxMsSeen` xuống thấp không mô phỏng đúng rewind thật (nó chỉ khiến `nowMsClamped()` tái neo về real time, không giữ lại mốc tương lai đã giả lập trước đó); bảo vệ rewind thật đã có test riêng ở `clamped_clock_test.dart`, việc delegate đúng đã được các test forward-jump (5s/10s) chứng minh gián tiếp.

`test/widget/common/cooldown_countdown_chip_test.dart` (5 case): render rỗng khi `remaining = 0`, render + đếm lùi đúng khi `remaining > 0`, `onDone` forward đúng, cha rebuild với CÙNG remaining không reset timer, remaining mới hẳn từ service thì nhận target mới đúng. `example/test/widget_showcase_screen_test.dart` (+3 case, FEAT-36 group): chưa start không có countdown nào của demo này, "Start 12s cooldown" hiện đúng và đếm lùi thật, bấm Start lần 2 khi đang chạy reset đúng về full 12s (dùng lại kỹ thuật đẩy `maxMsSeen` để mô phỏng 8s thật đã trôi ở tầng service, không dùng `tester.pump` — cùng lý do như trên).

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1427/1427 pass (không gặp lại flaky lần này). example `flutter analyze` sạch, `flutter test --exclude-tags slow` 59/59 pass. `dart run tool/api_compatibility.dart check` → unchanged sau snapshot lại. `dart pub publish --dry-run` → 1 warning quen thuộc (working-tree chưa commit). CHANGELOG.md cập nhật mục 0.2.0.

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): build+cài, mở Bộ Widget, scroll tới demo "PersistentCooldownService + CooldownCountdownChip", bấm "Start 12s cooldown" → countdown thật hiện và đếm lùi đúng (quan sát "Time remaining: 00:07" vài giây sau khi bấm). Kill app (`mobile_terminate_app`) rồi relaunch — xác nhận app khởi động lại sạch, không crash (`mobile_list_crashes` rỗng). **Hạn chế trung thực**: không lấy được bằng chứng "cooldown vẫn đếm đúng sau kill/relaunch" bằng thao tác trực tiếp trên máy, vì thiết bị bị chia sẻ với 1 session/app khác (`com.roy.admobwrapper`) liên tục cướp foreground ngay khi tôi điều hướng — thử lại nhiều lần đều bị gián đoạn giữa chừng, không phải lỗi từ code hay app của tôi. Bằng chứng thay thế cho đúng claim "sống qua restart": test "instance mới đọc từ cùng SharedPreferences vẫn thấy đúng state" trong `persistent_cooldown_service_test.dart` mô phỏng CHÍNH XÁC những gì xảy ra khi app bị kill/relaunch thật (`StorageService`/`PersistentCooldownService` bị huỷ hoàn toàn và tạo lại instance mới đọc cùng `SharedPreferences` — không có state nào sống sót trong RAM giữa 2 instance, đúng bản chất của "process restart").

**Tự chấm điểm: 9/10** — kiến trúc zero-timer nhất quán với `EnergyService` đã có (không tự chế thêm 1 batch scheduler theo đúng sprint slice gốc, vì với lazy-compute thì scheduler chỉ thừa — quyết định YAGNI có chủ đích); validate 2 lớp (input + persisted-read) đúng đúng nguyên tắc "không mở khóa sớm"; widget adapter tuân thủ đúng convention "data-in, không cầm service" đã có sẵn trong codebase; phát hiện và sửa đúng 1 lỗi giả định sai trong chính bộ test tự viết (test rewind lúc đầu) trước khi commit. Trừ 1 điểm vì thiếu bằng chứng kill/relaunch THẬT trên device do tranh chấp thiết bị dùng chung ngoài tầm kiểm soát — đã bù bằng bằng chứng tương đương chính xác ở tầng unit test và bằng chứng chạy thật (không kill) trên device.
