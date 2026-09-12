---
id: ENH-36
title: "Bổ sung test coverage cho fireHaptic() và ReminderService's init/permission/success path"
type: enhancement
priority: P3
effort: S
source: Codex (codex exec, audit test-gap lib/core/)
---

## Vị trí
`test/core/haptics_test.dart`, `test/core/reminder_service_test.dart`.

## Hiện trạng
`haptics_test.dart` chỉ test `hapticLevelForGroupSize` (pure function) — KHÔNG test gọi thật `fireHaptic()`, nên cờ enabled/soft-mode-downgrade/mapping tới platform method call cụ thể có thể regress mà không ai biết. `reminder_service_test.dart` chỉ chạy 1 test xác nhận exception bị nuốt khi KHÔNG có platform channel — chưa từng test init thành công, từ chối permission, tham số schedule đúng, huỷ lịch, hay 2 lệnh gọi đồng thời vào `_ensureInit()` khi `_initialized` vẫn false (race init).

## Vì sao cần / Hậu quả
2 service này thiếu bằng chứng test cho đúng hành vi chính của chúng — không phải bug đã biết, nhưng là lỗ hổng khiến 1 regression thật (ví dụ đổi sai platform method mapping cho `HapticLevel.heavy`, hoặc phá race-guard của `_ensureInit`) không bị bất kỳ test nào bắt.

## Đề xuất
Mock haptic platform channel, đăng ký storage, assert không gọi platform method nào khi `hapticsEnabled == false`, và đúng method call cho từng `HapticLevel` ở cả chế độ thường lẫn soft-mode (downgrade). Với `ReminderService`: inject/mock `FlutterLocalNotificationsPlugin`, assert đúng id/mode/thời gian khi schedule thành công, assert đúng id khi cancel, mô phỏng permission bị từ chối, và gọi `_ensureInit()` 2 lần đồng thời (trước khi lần đầu hoàn tất) để xác nhận chỉ init đúng 1 lần.

## Acceptance criteria
- [ ] fireHaptic() có test cho mọi HapticLevel ở cả 2 chế độ (thường/soft-mode), và test xác nhận không gọi platform method nào khi tắt trong settings.
- [ ] ReminderService có test cho: init thành công, permission bị từ chối, tham số schedule đúng, cancel đúng id, và 2 lệnh gọi _ensureInit() đồng thời chỉ init 1 lần.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-36-haptics-reminder-service-test-coverage-gap.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Thấp — đây là task chỉ bổ sung test, không sửa code sản xuất (trừ khi test lộ ra bug thật trong quá trình viết, thì báo cáo riêng). Effort thấp vì logic đã tồn tại, chỉ thiếu bằng chứng.
