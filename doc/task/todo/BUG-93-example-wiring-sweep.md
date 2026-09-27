---
id: BUG-93
title: "Example wiring sweep"
type: bug
priority: P1
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

(a) `example/lib/screens/game_demo_screen.dart:145`; (b) `lib/presentation/widgets/common/achievement_unlock_listener.dart:50`; (c) `example/lib/screens/widget_showcase_screen.dart:468`.

## Hiện trạng

(a) `_eventBus.subscribe<CircleTappedEvent>` trả `StreamSubscription`, bị vứt; dispose chỉ dispose bus dòng 235 nhưng không thấy cancel subscription event bus. (b) listener subscribe 1 lần `initState`, không `didUpdateWidget`; `review_prompt_trigger.dart:83` đã có mẫu resubscribe. (c) asset session dùng `GameSessionController()` trần, game demo đã cảnh báo phải Get.put để `onInit` chạy.

## Vì sao cần / Hậu quả

Leak subscription, stream thay đổi mất event, session lifecycle không chạy khi thiếu wiring đúng.

## Đề xuất

(a) giữ subscription và cancel trước dispose bus; (b) thêm `didUpdateWidget` resubscribe; (c) dùng cùng lifecycle registration như game demo.

## Acceptance criteria

- [ ] Mỗi mục có ít nhất 1 widget/unit test chứng minh cleanup/resubscribe/registration.
- [ ] Không double-cancel/free-after-dispose trong dispose path.

## Quyết định

_(điền sau khi implement + push: implementation, TDD, kết quả analyze/test, tự chấm điểm)_

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)

Đọc kỹ file task này trước khi làm. Đọc toàn bộ file source liên quan trước khi thiết kế. Implement bằng TDD.
Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test + integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ `example/`.
4. Smoke test trên device Android thật có bằng chứng (khi task đổi hành vi quan sát được).
Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.
Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, commit + push lần hai.

## Ghi chú độ tin cậy

Cao với (a) và (c); (b) verify initState subscribe dòng 50, không có `didUpdateWidget`, mẫu review prompt dòng 83 đã đúng. Riêng (a): `_unlockSub` dùng cho achievement stream; subscribe event bus trả về nhưng context chưa giữ.
