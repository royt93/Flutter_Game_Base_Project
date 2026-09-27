---
id: BUG-95
title: "Presentation freshness sweep"
type: bug
priority: P2
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

(a) `lib/presentation/widgets/common/confetti_overlay.dart:205`, `coin_fly_overlay.dart:237`, `flame_tracked_overlay.dart`; (b) `lib/presentation/widgets/common/energy_bar.dart:83`, game demo truyền snapshot dòng 364.

## Hiện trạng

(a) Confetti/Coin chỉ `IgnorePointer`, thiếu `ExcludeSemantics`; Flame overlay + StrokeText chưa có semantics label rõ. (b) Energy bar `Timer.periodic` riêng + nhận snapshot 1 lần, có thể stale khi service refill nền.

## Vì sao cần / Hậu quả

Screen reader đọc overlay trang trí; HUD energy sai sau refill nền.

## Đề xuất

(a) `ExcludeSemantics`/semantic label cho overlay trang trí + HUD; (b) lắng nghe service/reactive thay snapshot một lần.

## Acceptance criteria

- [ ] Semantics test pass cho overlay và HUD.
- [ ] Timer/freshness test: refill nền làm UI cập nhật.
- [ ] Không regression animation/confetti hiện tại.

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

Cao. Đã verify `IgnorePointer` tại confetti 205/coin 237, `Timer.periodic` energy 83, game demo truyền energy snapshot dòng 364.
