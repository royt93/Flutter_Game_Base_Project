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
- [ ] Demo trong `WidgetShowcaseScreen` (tutorial 2-3 bước qua nhiều widget khác nhau, không chỉ 1 target như demo hiện tại).
- [ ] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test.

## Ghi chú độ tin cậy
Trung bình — nhu cầu thật nhưng API shape (widget vs controller) cần bàn kỹ
trước khi code, không tự quyết định 1 mình. Compose từ `SpotlightOverlay`
có sẵn nên phần lõi (soi sáng) không phải viết lại, effort chủ yếu ở phần
state machine chuyển bước.
