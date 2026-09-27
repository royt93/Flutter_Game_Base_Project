---
id: BUG-91
title: "Demo pause không dừng Flame engine"
type: bug
priority: P0
effort: M
source: "fork audit core + verify phiên chính"
---

## Vị trí

`example/lib/screens/game_demo_screen.dart:405` FAB pause; `lib/presentation/game/roy_game.dart:215` `BouncingOrb.update`.

## Hiện trạng

FAB chỉ gọi `_session.pause(GamePauseReason.user)`. Không có `pauseEngine`/`resumeEngine` anywhere trong game demo; Flame vẫn tick `BouncingOrb.update`, orb chạy dưới overlay pause.

## Vì sao cần / Hậu quả

Pause UI nói game dừng nhưng simulation vẫn chạy. Collision/timer/gameplay thực sẽ sai và user mất tin tưởng.

## Đề xuất

Một helper duy nhất đồng bộ `GameSessionController` + Flame engine (`pauseEngine`/`resumeEngine`); PauseOverlay callback dùng cùng helper.

## Acceptance criteria

- [ ] Widget/device test: pause → orb/world đứng yên.
- [ ] Resume → orb/world chạy lại.
- [ ] User và system pause giữ đúng pause reason, engine chỉ resume khi mọi reason đã hết.

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

Cao. Đã verify FAB dòng 405 chỉ pause session, grep không thấy `pauseEngine`/`resumeEngine`, `BouncingOrb.update` dòng 215 luôn đổi position.
