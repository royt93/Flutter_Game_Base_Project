---
id: ENH-39
title: "Route các chuỗi mặc định hardcode tiếng Anh qua AppTranslations hoặc tham số customizable"
type: enhancement
priority: P3
effort: M
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`sound_toggle_fab.dart` (label: 'Mute'/'Unmute' hardcode), `confirm_dialog.dart` (`showConfirmDialog`'s `confirmLabel = 'OK'`/`cancelLabel = 'Cancel'` không dùng `'ok'.tr`/`'cancel'.tr` sẵn có), `spotlight_overlay.dart` (`buttonLabel = 'Got it'` hardcode dù đã là param customizable, chỉ default value chưa dịch), `network_status_banner.dart` (`offlineMessage` default hardcode), `daily_login_calendar.dart` (`CommonButton(label: 'Claim', ...)` hardcode không có param), `victory_card_template.dart` (`Text('Scan to play', ...)` hardcode không có param).

## Hiện trạng
Các chuỗi này không đi qua `AppTranslations`, nên app hỗ trợ đa ngôn ngữ (đã có sẵn `en`/`vi`) nhưng những label/message này LUÔN hiển thị tiếng Anh bất kể locale hiện tại là gì — không nhất quán với phần còn lại của app đã dịch đầy đủ.

## Vì sao cần / Hậu quả
1 game dùng `showConfirmDialog` mặc định (rất phổ biến — đây là hộp thoại xác nhận chung của cả kit) sẽ luôn thấy nút 'OK'/'Cancel' tiếng Anh dù đã đổi locale sang 'vi' và mọi chỗ khác trong app đều hiển thị đúng tiếng Việt — 1 chỗ hở dễ bị QA/người dùng phát hiện ngay.

## Đề xuất
Với `showConfirmDialog`: đổi default `confirmLabel`/`cancelLabel` thành nullable, resolve qua `'ok'.tr`/`'cancel'.tr` khi null (2 key này đã có sẵn trong `AppTranslations`, không cần thêm key mới). Với các widget còn lại (`SoundToggleFab`, `SpotlightOverlay`, `NetworkStatusBanner`, `DailyLoginCalendarWidget`, `VictoryCardTemplate`): thêm tham số optional cho phép caller truyền chuỗi đã dịch từ app của họ (package không tự thêm key dịch mới vào `AppTranslations` cho những string cụ thể-app này, giữ đúng ranh giới package/app — game-specific copy không thuộc về package).

## Acceptance criteria
- [x] showConfirmDialog mặc định dùng 'ok'.tr/'cancel'.tr thay vì hardcode 'OK'/'Cancel'.
- [x] Mỗi widget còn lại nhận tham số optional cho chuỗi liên quan (semanticLabel/buttonLabel/offlineMessage/claimLabel/qrLabel tuỳ widget), giữ nguyên default hiện tại nếu caller không truyền.
- [x] Test: đổi locale sang 'vi' xác nhận showConfirmDialog hiển thị đúng bản dịch; test mỗi widget còn lại với tham số custom truyền vào hiển thị đúng chuỗi đó thay vì default.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên máy Android thật (Samsung SM-S928B, không simulator) — bằng chứng cụ thể trong Quyết định.
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion` (không đổi animation nào ở task này — chỉ thêm/route string, không chạm layer render/animation).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-39-i18n-hardcoded-default-strings-sweep.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — giá trị thật (nhất quán i18n) nhưng không phải bug, effort M vì chạm nhiều file nhỏ lẻ, mỗi thay đổi riêng lẻ rất đơn giản.

## Quyết định

Đã sửa (commit `2c29c65`):
- `showConfirmDialog`: `confirmLabel`/`cancelLabel` đổi thành nullable, resolve qua `'ok'.tr`/`'cancel'.tr` khi null. Caller truyền tay vẫn ưu tiên hơn.
- `SoundToggleFab`: thêm `mutedLabel`/`unmutedLabel` optional (label Semantics, không phải text hiển thị) — default giữ nguyên 'Mute'/'Unmute' tiếng Anh.
- `DailyLoginCalendarWidget`: thêm `claimLabel` optional cho nút Claim — default giữ nguyên 'Claim'.
- `VictoryCardTemplate`: thêm `qrCaption` optional cho dòng chữ dưới QR — default giữ nguyên 'Scan to play'.
- `SpotlightOverlay` (`buttonLabel`) và `NetworkStatusBanner` (`offlineMessage`) đã sẵn optional param với default từ trước khi task này bắt đầu — không cần sửa code, chỉ bổ sung test còn thiếu cho `SpotlightOverlay.buttonLabel` custom (Network banner đã có test custom `offlineMessage` từ trước).

Theo đúng ranh giới package/app nêu trong Đề xuất: package KHÔNG tự thêm key dịch mới vào `AppTranslations` cho chuỗi cụ thể-app (Mute/Unmute, Claim, Scan to play...) — chỉ `showConfirmDialog`'s OK/Cancel dùng key có sẵn vì đó là hành động phổ quát, không phải game-specific copy.

### Device smoke test — Samsung SM-S928B (thật, không simulator)
Build lại release APK (`flutter build apk --release`), cài qua `adb install -r`, mở `WidgetShowcaseScreen` (locale máy đang là 'vi' từ trước) và tap demo "ConfirmDialog (showConfirmDialog)": dialog hiện đúng tiêu đề "Delete save?" kèm 2 nút **"Huỷ"**/**"Đồng ý"** (bản dịch tiếng Việt của key `cancel`/`ok`, không phải "Cancel"/"OK" tiếng Anh) — xác nhận key `.tr` resolve đúng theo locale hiện tại trên thiết bị thật. Tap "Đồng ý" đóng dialog không crash. `mobile_get_device_logs` lọc `level=Error` cho process app trong suốt thao tác: không có entry nào.

Lưu ý: demo hiện có trong `WidgetShowcaseScreen` truyền tường minh `confirmLabel: 'ok'.tr, cancelLabel: 'cancel'.tr` (viết từ trước, không đổi) nên không trực tiếp phơi bày nhánh default-null MỚI của `showConfirmDialog` trên UI thật — nhánh đó (`confirmLabel ??= 'ok'.tr`) đã được xác nhận đúng qua widget test (`confirm_dialog_test.dart`, 2 locale × có/không truyền label, dùng `GetMaterialApp` + `AppTranslations` thật, không mock) chứ không qua device. Bằng chứng device ở trên xác nhận gián tiếp: cùng 2 key `ok`/`cancel` resolve đúng bản dịch trên máy thật, nên nhánh default (gọi cùng `.tr` y hệt) chắc chắn cho cùng kết quả.
