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

- [x] Content history retention cap, tamper reject, downgrade reject, explicit rollback success.
- [x] Diagnostics không chứa content body/PII, chỉ version/checksum.
- [x] Timeline fake-clock deterministic, ghi pause reasons/outcome, restart reset session.
- [x] Timeline cap chặn growth vô hạn; export round-trip.

## Quyết định

### RemoteContentPack history/rollback
- Giữ nguyên 2 constructors cũ; thêm additive `RemoteContentPack.withHistory(...)` với runtime validation `historyCapacity > 0`, default `contentVersionResolver` (`contentVersion` → `version` → `0`), history key riêng `${cacheKey}_history_v1`.
- Public metadata-only `ContentPackHistoryEntry`, read-only `history`, `currentContentVersion`, `currentChecksum`, `diagnosticsSummary()` — không expose raw content body/PII.
- Remote apply: verify HMAC → schema validate/migrate → resolve contentVersion → reject downgrade → write current cache → append/persist capped history → swap `_current`.
- Additive rollback: `rollbackToChecksum`/`rollbackToVersion` trả `SdkResult<T>`, chọn bản mới nhất khi version trùng, persist trước khi swap current.
- Tests trong `test/core/remote_content_pack_test.dart`: constructor cap validation; FIFO cap; persistence qua restart; downgrade reject; tamper reject; rollback checksum/version (kể cả restart); missing target typed failure; diagnostics không body/PII; resolver fallback/custom path.

### GameSessionController timeline
- Giữ nguyên `events`, existing constructors, `win()/lose()` signatures; thêm additive `GameSessionController.withTimeline(...)`, runtime validation `timelineCapacity > 0`, injected Stopwatch factory, default-deny metadata allowlist + `ReproductionCapsule.defaultRedactedKeys` blacklist (blacklist thắng allowlist).
- Models additive `GameSessionTimelineEntry`/`GameSessionTimelineExport` với `toJson/fromJson`; `winWithMetadata`/`loseWithMetadata`; capped read-only `timeline`; `exportTimeline()` không wall-clock/device/user identifier.
- Timeline ghi monotonic offset, phase, full pauseReasons; overlapping reason changes tạo entry riêng dù legacy `events` không đổi phase; restart reset stopwatch+timeline về `loading@0`.
- Tests trong `test/core/game_session_controller_test.dart`: fake Stopwatch offsets deterministic; pause/outcome metadata; allowlist+PII blacklist; cap eviction; restart reset; export JSON round-trip/PII-free; legacy APIs unchanged.

### Demo/proof
- Cookbook tiles thật cho content history apply→rollback và session timeline export (không static label), cùng 2 widget tests tương ứng trong `example/test/cookbook_screen_test.dart`.
- API compatibility snapshot regenerate; `dart run tool/api_compatibility.dart check` → `unchanged`.

Gates: root+example `flutter analyze` sạch; root full suite 2601/2601 pass; example full suite 206/206 pass; all quality-gate scripts pass; publish dry-run chỉ còn expected warning/hint.

Tự chấm: 9.5/10 — toàn bộ API additive, legacy behavior giữ nguyên, security/privacy boundary explicit và có test fail-safe.

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
