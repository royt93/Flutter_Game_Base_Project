---
id: ENH-96
title: "Content history và session outcome timeline"
type: enhancement
priority: P2
effort: M
source: "differentiator độc quyền"
---

## Vị trí

(a) `lib/core/remote_content_pack.dart` (`_current`, verify/schema apply); (b) `lib/core/game_session_controller.dart:6-23,91-98`, tích hợp replay/diagnostics.

## Hiện trạng

(a) Content pack chỉ giữ một `_current` trong RAM, không activation history/retention/downgrade guard. (b) Session chỉ giữ `events` là list phase; mất monotonic offset, pause reason, outcome metadata; `restart` xóa list đúng nhưng không có export PII-free cho diagnostics/replay.

## Vì sao cần / Hậu quả

Không điều tra được "content version nào active khi lỗi" hay timeline session chính xác; rollback content không audit được.

## Đề xuất

(a) giữ N bản verified, từ chối downgrade trừ rollback tường minh; diagnostics chỉ version/checksum. (b) immutable timeline entries có monotonic offset + transition + pause reason; restart mở session mới/xóa timeline; export PII-free/capped cho replay/diagnostics.

## Acceptance criteria

- [ ] Content history retention cap, tamper reject, downgrade reject, explicit rollback success.
- [ ] Diagnostics không chứa content body/PII, chỉ version/checksum.
- [ ] Timeline fake-clock deterministic, ghi pause reasons/outcome, restart reset session.
- [ ] Timeline cap chặn growth vô hạn; export round-trip.

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

Cao. Đã verify RemoteContentPack chỉ có một `_current`/không history; GameSessionController `events` chỉ `RxList<GameSessionPhase>`, restart assign `[loading]`, snapshot có pauseReasons nhưng event history không ghi reason/time.
