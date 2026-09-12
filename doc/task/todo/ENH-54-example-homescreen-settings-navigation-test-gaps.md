---
id: ENH-54
title: "example/: HomeScreen navigation, SettingsScreen language picker, RewardPopup dismiss, ScreenShake decay chưa được test thật"
type: enhancement
priority: P3
effort: M
source: Claude fork, audit example/ app
---

## Vị trí
`example/test/settings_screen_test.dart`, `example/test/widget_showcase_screen_test.dart`, `example/lib/screens/home_screen.dart`, `example/lib/screens/settings_screen.dart` (`_pickLanguage`), `lib/presentation/widgets/common/screen_shake.dart` (`ScreenShakeController.offsetAt`).

## Hiện trạng
4 lỗ hổng cụ thể: (1) `HomeScreen` test chỉ check text 'Settings' xuất hiện, KHÔNG tap bất kỳ nút nào trong 3 nút điều hướng (`Get.to` tới Settings/WidgetShowcase/GameDemo) — 0% navigation coverage thật. (2) `_pickLanguage` (bottom sheet chọn locale) không hề được tap/test trong `settings_screen_test.dart`. (3) Test "RewardPopup dismiss" chỉ assert `tester.takeException()` rỗng sau khi tap barrier, KHÔNG xác nhận popup đã thực sự biến mất (`find.text('Level Complete!')` findsNothing) — 1 regression làm barrier tap ngừng đóng popup vẫn PASS test này. (4) Test ScreenShake tự nhận trong comment là chỉ check "không throw", chưa từng đọc `ScreenShakeController.offsetAt(...)` (hàm pure, dễ test) để xác nhận rung thật sự xảy ra rồi decay về 0.

## Vì sao cần / Hậu quả
Cả 4 chỗ này là test giả ("crash-only" test) đứng thế chỗ cho verify hành vi thật — 1 regression thật ở bất kỳ chỗ nào trong 4 chỗ này (navigation gãy, language picker không đổi locale, popup không đóng được, screen shake không rung) đều lọt qua CI mà không ai biết.

## Đề xuất
Viết lại/bổ sung 4 test theo đúng pattern verify-thật đã có sẵn trong cùng file cho các demo khác (ví dụ SpotlightOverlay dismiss test đã làm đúng cách): tap từng nút Home, assert `find.byType(<Screen>)` xuất hiện đúng; tap Language row rồi tap 1 locale, assert `LocaleService.current` đổi và subtitle cập nhật; sau khi tap barrier đóng RewardPopup, thêm assert `find.text('Level Complete!'), findsNothing`; sau khi tap Shake!, đọc `ScreenShakeController.offsetAt(...)` xác nhận khác 0 ngay sau đó rồi = 0 sau khi decay.

## Acceptance criteria
- [ ] 3 nút điều hướng trên HomeScreen đều có test tap + assert đúng screen đích xuất hiện.
- [ ] _pickLanguage có test tap mở sheet, chọn 1 locale khác, xác nhận LocaleService.current đổi đúng và UI cập nhật.
- [ ] Test RewardPopup dismiss xác nhận popup thực sự biến mất, không chỉ 'không throw'.
- [ ] Test ScreenShake xác nhận offsetAt(...) khác 0 ngay sau tap và = 0 sau decay, không chỉ 'không throw'.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-54-example-homescreen-settings-navigation-test-gaps.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao độ tin cậy (đọc code xác nhận, không suy đoán) — đây toàn là bổ sung test, không sửa code sản xuất (trừ khi phát hiện bug thật trong lúc viết, báo cáo riêng khi đó).
