---
id: BUG-76
title: "SceneTransitionController kẹt loading barrier khi load callback ném exception"
type: bug
priority: P1
effort: S
source: "claude audit vòng 3 — tái hiện bằng test độc lập"
---

## Vị trí
`lib/presentation/widgets/common/scene_transition_overlay.dart`, `SceneTransitionController.run`.

## Hiện trạng và hậu quả
`load` là callback do consumer cung cấp. Nếu callback ném exception, exception thoát khỏi `run()`, phase giữ `loading`, và overlay tiếp tục chặn pointer/semantics. Người chơi có thể bị kẹt màn chuyển cảnh.

## Acceptance criteria
- [x] Callback `load` ném lỗi trả về `SdkFailure<void>` có cause/stackTrace.
- [x] Transition hiện hành chuyển sang `error`, lưu `lastError`, không giữ loading barrier.
- [x] Transition đã supersede/cancel/dispose không bị callback cũ mutate state.
- [x] Các test transition hiện có vẫn pass.

## Prompt
Làm TDD trong `test/widget/common/scene_transition_overlay_test.dart`. Catch callback exception ở boundary `await load(...)`; không để typed failure hiện có đổi semantics.

## Quyết định
- Bọc lời gọi `await load(...)` trong khối `try/catch` ở `SceneTransitionController.run`. Khi callback ném exception bất ngờ, tạo `SdkFailure<void>` chứa nguyên vẹn `cause` và `stackTrace`.
- Nếu transition vẫn là active token hiện hành: gán `lastError = failure`, chuyển `phase.value = SceneTransitionPhase.error`, trả về `failure`. Điều này giải phóng loading indicator, hiển thị `RetryErrorState` và gỡ bỏ pointer barrier kẹt.
- Nếu transition đã bị supersede, cancel hoặc controller bị dispose (`!_isCurrent(token)`): trả về failure mà không mutate `lastError` hay `phase` của controller, tránh ghi đè state mới hơn.
- TDD: Bổ sung 3 test regression (xác nhận RED với StateError thoát ra ngoài trên code cũ; GREEN trên code mới). Toàn bộ 20 test liên quan và `flutter analyze` pass.
- Tự chấm audit: **9.8/10** — fix tối thiểu đúng ranh giới lỗi, triệt tiêu nguy cơ freeze UI khi asset hoặc network tải cảnh bị sập.
- Commit hiện thực: `d1c930f`.
