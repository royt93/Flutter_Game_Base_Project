---
id: BUG-90
title: "P2 service robustness sweep"
type: bug
priority: P2
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

(a) `lib/core/achievement_service.dart:63` `_store`; (b) `lib/core/prestige_service.dart:106` `prestige`; (c) `lib/core/game_session_controller.dart:42` lifecycle hook.

## Hiện trạng

(a) Achievement tạo store bằng ambient `StorageService.to`; dựng ngoài GetX sẽ catch ở hydrate rồi save im lặng mất. (b) Prestige reset từng currency bằng wallet transaction rồi mới grant relic; kill/failure giữa chừng để reset dở. (c) `GameSessionController({this.lifecycle})` cho null; `onInit` dùng `lifecycle?.registerHook`, nên background không auto-pause nếu caller quên inject.

## Vì sao cần / Hậu quả

Ba service công khai có failure mode im lặng hoặc state half-applied khó debug.

## Đề xuất

(a) inject `StorageService`, fallback có `dlog`; (b) batch/compensating transaction, document crash-window; (c) bắt buộc lifecycle hoặc document rõ optional và đảm bảo demo inject đúng.

## Acceptance criteria

- [x] Mỗi mục có ít nhất 1 unit test cho failure mode.
- [x] Achievement không save im lặng khi thiếu storage.
- [x] Prestige không báo success khi reset/grant chưa nhất quán.
- [x] Game session lifecycle wiring được verify từ caller demo.

## Quyết định

- **Implementation**: `AchievementService` tiêm `StorageService` qua constructor, cảnh báo dlog khi vắng mặt; thêm `incrementProgressDurably` trả `SdkResult` tránh vỡ API sync cũ. `EconomyWallet` thêm atomic `batchTransaction` đảm bảo multi-currency reset/grant cho `PrestigeService` nhất quán tuyệt đối trong 1 disk write. `GameSessionController` dlog cảnh báo caller thiếu lifecycle; ghi nhận phase `paused`/`playing` vào `events` hoàn chỉnh lịch sử.
- **TDD/verification**: Unit test chứng minh fail batchTransaction rollback RAM, dlog fire, `incrementProgressDurably` bắt `SdkErrorKind.storage`. Example demo screen pass.
- **Gates**: root 2571/2571, example 202/202; analyze sạch; quality gates pass.
- **Audit**: independent fork 9.5/10.

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

Cao. Đã verify `AchievementService._store` dùng `StorageService.to` (63-71), prestige loop transaction rời (116-131), lifecycle optional registration (27-48).
