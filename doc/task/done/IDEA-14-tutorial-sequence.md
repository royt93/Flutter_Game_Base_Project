---
id: IDEA-14
title: "TutorialSequence — orchestrator nối nhiều SpotlightOverlay thành 1 chuỗi hướng dẫn nhiều bước"
type: idea
priority: P3
effort: S-M
source: Claude, đề xuất feature mới (round 5)
---

## Ý tưởng
`SpotlightOverlay` (đã có, dùng trong demo "Start tutorial" của
`WidgetShowcaseScreen`) chỉ soi sáng **1 target duy nhất** tại 1 thời điểm
— caller tự quản lý bước nào đang hiện, tự gọi lại `SpotlightOverlay` khác
khi bước trước xong. Không có helper nào orchestrate 1 chuỗi nhiều bước
(soi target A → tap → soi target B → tap → ... → hết tutorial).

## Vì sao cần
Tutorial nhiều bước là nhu cầu rất phổ biến (onboarding lần đầu mở app),
và hiện tại consumer app phải tự viết state machine (bước hiện tại, next,
skip toàn bộ) bằng tay — lặp lại logic ở mọi game dùng kit.

## Đề xuất
`TutorialSequence` — không phải widget vẽ ra UI mới, mà 1 controller/
helper nhận `List<TutorialStep>` (mỗi step: `GlobalKey targetKey`,
`String message`, optional `onBeforeShow`), expose `start()`/`next()`/
`skip()`, và tự dựng `SpotlightOverlay` cho bước hiện tại (compose, không
viết lại logic soi sáng). Có thể là 1 `StatefulWidget` wrapper (giống cách
`DebugQaOverlay` bọc quanh app) hoặc 1 class điều khiển thuần + để caller
tự quyết render — cần thiết kế kỹ trước khi chọn hướng nào.

## Acceptance criteria
- [ ] Quyết định rõ hình dạng API (widget wrapper hay controller thuần) trước khi code.
- [ ] Test TDD: next()/skip() chuyển đúng bước, gọi xong bước cuối thì tự đóng, `onBeforeShow` (nếu có) chạy trước khi soi target.
- [x] Demo trong `WidgetShowcaseScreen` (tutorial 2-3 bước qua nhiều widget khác nhau, không chỉ 1 target như demo hiện tại).
- [x] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test.

## Quyết định
API shape: controller thuần — `TutorialSequenceController extends
ChangeNotifier` (caller tự tạo/sở hữu, đúng pattern `ScreenShakeController`
đã có trong `screen_shake.dart`, không phải `GetxService` toàn cục vì state
này cục bộ theo 1 lần chạy tutorial). `TutorialSequence` là
`StatefulWidget` bọc quanh `child`, tự dựng `SpotlightOverlay` cho bước
hiện tại (compose, không viết lại logic soi sáng), `onDismiss` tự gọi
`controller.next()`. Có thêm `onComplete` callback (không có trong đề xuất
gốc) — bắn khi chuỗi kết thúc (hết bước hoặc `skip()`), tiện cho app lưu
"đã xem tutorial". TDD: viết test trước cho cả controller (start/next/skip)
và widget (hiện/ẩn overlay, dismiss tự next, onComplete), xác nhận fail
đúng lý do trước khi code. Demo nối 2 target có sẵn (`_spotlightTargetKey`,
`_coinCounterKey`) thay vì tạo key mới. Verify: `flutter analyze` sạch +
`flutter test` 440 pass ở root (434+6 mới), 29 pass ở `example/`. Device
smoke trên Pixel 7 Pro thật: start → dim scrim hiện đúng (target ngoài màn
hình do vị trí demo ở cuối trang dài — cùng hạn chế đã biết từ demo
`SpotlightOverlay` gốc, comment code cũ đã ghi "scroll up after dismissing
to see which one it was"), tap dismiss 2 lần → chuỗi tự đóng đúng, không
exception, scroll lại bình thường sau khi đóng.

## Ghi chú độ tin cậy
Trung bình — nhu cầu thật nhưng API shape (widget vs controller) cần bàn kỹ
trước khi code, không tự quyết định 1 mình. Compose từ `SpotlightOverlay`
có sẵn nên phần lõi (soi sáng) không phải viết lại, effort chủ yếu ở phần
state machine chuyển bước.
