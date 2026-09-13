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
- [x] 3 nút điều hướng trên HomeScreen đều có test tap + assert đúng screen đích xuất hiện.
- [x] _pickLanguage có test tap mở sheet, chọn 1 locale khác, xác nhận LocaleService.current đổi đúng và UI cập nhật.
- [x] Test RewardPopup dismiss xác nhận popup thực sự biến mất, không chỉ 'không throw'.
- [x] Test ScreenShake xác nhận offsetAt(...) khác 0 ngay sau tap và = 0 sau decay, không chỉ 'không throw' (đo qua Transform.translate thật do ScreenShake render ra, phản ánh trực tiếp offsetAt(...)).
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên máy Android thật (Samsung SM-S928B, không simulator) — bằng chứng cụ thể trong Quyết định.
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion` (task này không sửa code sản xuất/animation nào — chỉ test).

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

## Quyết định

Không phát hiện bug sản xuất nào trong lúc viết — cả 4 test gap đều đã được lấp mà không cần sửa `home_screen.dart`/`settings_screen.dart`/`screen_shake.dart`. Toàn bộ thay đổi nằm trong `example/test/settings_screen_test.dart` và `example/test/widget_showcase_screen_test.dart` (commit `276d88c`).

### Ghi chú kỹ thuật đáng chú ý
- **HomeScreen navigation test**: tap trực tiếp lên `Text` render bởi `StrokeText` (label của `NeonButton`) không ổn định — `StrokeText` vẽ 2 `Text` chồng nhau (stroke + fill) và `find.widgetWithText(NeonButton, ...)` trả về 2 match trùng cho cùng 1 `NeonButton` (khớp theo từng `Text` con) → phải thêm `.first`. Assertion ban đầu `find.byType(HomeScreen), findsNothing` sau khi `Get.to()` là SAI — `Navigator` giữ route cũ mounted bên dưới (offstage), không unmount; sửa lại chỉ assert đúng screen ĐÍCH đã xuất hiện.
- **`_pickLanguage` bottom sheet**: tap thẳng vào toạ độ màn hình của row locale trong sheet không đáng tin cậy trong widget test — `AnimationController` của `showModalBottomSheet` chỉ thực sự bắt đầu tick ở frame ĐẦU TIÊN của chính nó, nên 1 `pump(duration)` lớn duy nhất ngay sau tap đo sai elapsed time thực tế của transition (đã verify bằng debug script: sau 1 `pump(300ms)`, row vẫn nằm ở vị trí y ngoài viewport). Thay vì cố canh thời gian pump chính xác, test gọi thẳng `CommonListTile.onTap!()` của row đó — vẫn đúng cùng 1 callback thật mà `_pickLanguage` gán, chỉ bỏ qua việc phải mô phỏng đúng toạ độ pixel giữa lúc đang animate.
- **ScreenShake**: đọc trực tiếp `Transform.translate` mà `ScreenShake` tự render (không cần truy cập field private `_screenShakeController` của `WidgetShowcaseScreen`) — phản ánh đúng giá trị `controller.offsetAt(...)` tại thời điểm đó vì đó chính xác là điều `ScreenShake`'s `build()` dùng để vẽ.

### Device smoke test — Samsung SM-S928B (thật, không simulator)
Task này không sửa code sản xuất nên không cần rebuild APK — dùng lại bản đã cài (từ ENH-38). Mở app thật, vào Cài đặt → tap "Ngôn ngữ" → sheet mở đúng (VI đang check) → tap "EN" → **locale đổi thật ngay lập tức**, toàn bộ UI dịch lại sang tiếng Anh ("Settings", "Sound", "Dark Mode", "Language: EN") — xác nhận đúng hành vi mà test mới viết đang bảo vệ. Đổi lại VI để khôi phục trạng thái máy. `mobile_get_device_logs` lọc `level=Error`: không có lỗi nào trong suốt thao tác.
