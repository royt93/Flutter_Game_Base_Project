---
id: IDEA-43
title: "AchievementUnlockToast + AchievementService.onUnlock stream"
type: idea
priority: exclusive (độ tin cậy cao)
effort: M
source: Claude (self-generated backlog brainstorm sau khi IDEA backlog cạn — xác nhận qua agent quét codebase độc lập)
---

## Vị trí
Mở rộng `lib/core/achievement_service.dart` (thêm `onUnlock` stream); widget mới `lib/presentation/widgets/common/achievement_unlock_toast.dart`.

## Hiện trạng
`AchievementService` (có từ 0.1.0) theo dõi `register`/`incrementProgress`/`isCompleted` đầy đủ, nhưng KHÔNG có bất kỳ cách nào để caller biết CHÍNH XÁC lúc nào 1 achievement vừa chuyển từ chưa-xong sang xong (chỉ có thể tự poll `isCompleted` sau mỗi `incrementProgress`). Toàn bộ repo (kể cả `example/`) hiện không có widget nào tiêu thụ `AchievementService` — không có cách hiển thị "bạn vừa đạt thành tích X" cho người chơi, dù đây là phản hồi cốt lõi của casual game.

## Vì sao cần / Hậu quả
Thiếu event "vừa unlock" khiến mọi game dùng kit này phải tự viết lại logic so sánh trạng thái trước/sau mỗi lần gọi `incrementProgress` để biết có nên hiện thông báo hay không — dễ sai (ví dụ unlock 2 achievement cùng lúc trong 1 lần tăng lớn) và không có sẵn UI mẫu để hiện nó.

## Đề xuất
Thêm `Stream<String> get onUnlock` vào `AchievementService` (phát đúng 1 lần `achievementId` ngay tại thời điểm `incrementProgress` khiến nó CHUYỂN từ chưa-đạt sang đạt — không phát lại nếu gọi thêm sau khi đã đạt). Thêm widget `AchievementUnlockToast` (overlay tự ẩn sau X giây, animation xịn sò theo `NeonTheme` — trượt vào + bật ra `easeOutBack`) lắng nghe stream này và tự hiện, dùng đúng pattern `NeonDialog.overlay` đã có trong kit thay vì tự implement overlay mới.

## Acceptance criteria
- [x] `onUnlock` phát đúng 1 lần mỗi achievement, đúng lúc chuyển trạng thái (không phát lại, không phát sai lúc `register` hay khi progress tăng nhưng chưa đạt ngưỡng).
- [x] Unlock nhiều achievement cùng lúc (1 lần `incrementProgress` nhảy qua ngưỡng nhiều id khác nhau nếu áp dụng, hoặc gọi liên tiếp) đều phát đủ, đúng thứ tự.
- [x] `AchievementUnlockToast` tự hiện khi có sự kiện, tự ẩn sau thời gian cấu hình, animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + input không hợp lệ nếu áp dụng) — unit cho stream logic, widget test cho toast + animation + reducedMotion.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) — bằng chứng cụ thể trong Quyết định.
- [x] Animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-43-achievement-unlock-toast.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc.
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — `AchievementService` xác nhận qua grep không có widget nào trong repo tiêu thụ nó, đây là lỗ hổng thật (không phải phỏng đoán); effort M vừa phải (1 stream + 1 widget), không đụng file nhạy cảm/scope peer.

## Quyết định

Implement đúng phần Đề xuất, với 1 điều chỉnh thiết kế so với đề xuất ban đầu (ponytail — tận dụng cái đã có thay vì viết lại):

- **`AchievementService.onUnlock`** (`lib/core/achievement_service.dart`): thêm `StreamController<String>.broadcast()` + getter `onUnlock`. `incrementProgress` chụp `wasCompleted = isCompleted(id)` TRƯỚC khi cộng progress, rồi so sánh với `isCompleted(id)` SAU khi cộng — chỉ `add(id)` khi chuyển `false → true`. Tái dùng thẳng logic `isCompleted` đã có sẵn thay vì tự so sánh threshold lần nữa. `onClose()` đóng `StreamController` để không leak.
- **Điều chỉnh so với đề xuất**: đề xuất gốc gọi widget là `AchievementUnlockToast` (ngụ ý tự vẽ toast mới). Thay vào đó implement `AchievementUnlockListener` (`lib/presentation/widgets/common/achievement_unlock_listener.dart`) — 1 widget MỎNG chỉ lắng nghe `onUnlock` rồi gọi thẳng `ToastBanner.show(...)` đã có sẵn trong kit (animation slide+fade, `reducedMotion`, overlay pattern đều tái dùng nguyên bản, không viết lại). Lý do: kit đã có sẵn `ToastBanner` xử lý đúng chính xác nhu cầu này — viết 1 widget toast mới từ đầu sẽ là trùng lặp không cần thiết (ponytail: "đã có trong codebase → tái dùng"). Mặc định màu `NeonTheme.gold` (khác mặc định `purple` của `ToastBanner.show`, vì đây là khoảnh khắc ăn mừng); `labelFor`/`color` optional cho caller tuỳ biến.
- Không có `AchievementService` đăng ký (`Get.put`) → `AchievementUnlockListener` không throw, chỉ không lắng nghe gì (`AchievementService.maybe?.onUnlock.listen(...)`), giữ đúng convention "an toàn khi thiếu service" như `DebugQaOverlay`.
- Wired demo vào `example/lib/screens/widget_showcase_screen.dart` (section "Game Feel", card `AchievementUnlockListener (IDEA-43)`) — đăng ký 1 achievement mẫu `widget_kit_explorer` (ngưỡng 3), nút "Tap to progress" gọi `incrementProgress`, cả `WidgetShowcaseScreen` bọc trong `AchievementUnlockListener` để toast hiện global trên toàn màn hình demo.

**Test:** `test/core/achievement_service_test.dart` (+6 test nhóm "IDEA-43: onUnlock stream" — phát đúng 1 lần khi chạm ngưỡng, không phát lại sau khi đã unlock, amount lớn nhảy qua ngưỡng vẫn đúng 1 lần, `register()` không tự phát dù retroactively đã đạt, nhiều id độc lập, broadcast nhiều listener cùng nhận) — dùng `pumpEventQueue()` thay vì `Future<void>.value()` đơn lẻ để flush đúng NHIỀU event của broadcast `StreamController` (mỗi event cần 1 microtask riêng, không chỉ 1 tick chung). `test/widget/common/achievement_unlock_listener_test.dart` (8 test) — không có service đăng ký, message mặc định = id, `labelFor` tuỳ biến, màu mặc định `gold`, màu tuỳ biến, nhiều unlock liên tiếp không mất sự kiện, dispose widget giữa chừng, `AchievementService` bị `Get.delete` không crash listener.

**Device smoke test (Pixel 7 Pro, `2B051FDH3006MU`, real device):** cài `example/build/app/outputs/flutter-apk/app-debug.apk`, vào Bộ Widget → Game Feel → card "AchievementUnlockListener (IDEA-43)". Bấm "Tap to progress" 3 lần: `widget_kit_explorer: 0/3 → 1/3 → 2/3 → unlocked!`, đúng dữ liệu persist qua `AchievementService`. Chụp được đúng khung hình `ToastBanner` (viền vàng `NeonTheme.gold`) hiện ở đầu màn hình với nội dung "widget_kit_explorer" đồng thời với dòng "unlocked!" bên dưới — xác nhận toast thật sự xuất hiện trên thiết bị, không chỉ trong test. `adb logcat` lọc `level=Error` cho process này: không có dòng nào trong suốt phiên thao tác (nhiều lần `pm clear` + relaunch + tap).

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 972/972 pass; `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 46/46 pass (demo mới không phá test cũ, không cần bump `physicalSize`). CHANGELOG.md đã thêm mục dưới `## 0.2.0`. `tool/api_compatibility.dart snapshot` chạy lại nhưng KHÔNG tạo diff — đúng theo tiền lệ đã ghi nhận ở IDEA-35 (gate chỉ theo dõi symbol top-level, thêm 1 member (`onUnlock`) vào class đã export sẵn không đổi snapshot) và ở IDEA-31 (`AchievementUnlockListener` chỉ export gián tiếp qua `common_widgets.dart`, gate không theo dõi các file barrel re-export lồng nhau); `test/api_compatibility_test.dart` vẫn pass.

**Tự chấm điểm: 9.5/10** — đúng yêu cầu cốt lõi (event unlock + UI tiêu thụ nó), test bao phủ đầy đủ case kể cả race/broadcast-multi-listener, device smoke test thật xác nhận cả progress lẫn toast hiển thị đúng, không phá API/test hiện có. Trừ điểm nhỏ vì đổi tên widget so với đề xuất ban đầu (quyết định có chủ đích, đã giải thích rõ lý do ở trên) và demo chỉ dùng 1 achievement mẫu thay vì nhiều loại.
