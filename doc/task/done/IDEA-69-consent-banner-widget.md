---
id: IDEA-69
title: "ConsentBannerWidget — UI thu thập consent còn thiếu cho ConsentStateService"
type: idea
priority: low
effort: S
source: "claude (fork brainstorm, độc lập)"
---

## Vị trí
Widget mới `lib/presentation/widgets/common/consent_banner.dart`, wrap `lib/core/consent_state_service.dart` (`ConsentStateService`, đã có, thuần state không UI) + `lib/core/onboarding_coordinator_service.dart` (`OnboardingCoordinatorService`, tái dùng để track "đã hỏi chưa").

## Hiện trạng
`ConsentStateService`/`ConsentGatedAnalyticsProvider` (đã done từ trước) chặn đúng analytics khi chưa consent (`grant(ConsentCategory)`/`deny(ConsentCategory)`/`reset(ConsentCategory)`, `ConsentCategory` gồm `analytics`/`personalization`), nhưng KHÔNG CÓ CÁCH nào trong package để người chơi THỰC SỰ cấp/từ chối consent qua UI — game phải tự viết banner từ đầu. Cùng lớp gap "state có sẵn nhưng thiếu widget" mà `SaveHealthCard` (IDEA-59) từng lấp cho `save_integrity.dart`.

## Vì sao cần / Hậu quả
GDPR/CCPA consent banner là thứ hầu như mọi game thật cần khi target thị trường EU/California — đây là gap rõ ràng giữa "hạ tầng có" và "dùng được ngay", không phải tính năng phổ biến nhưng có giá trị differentiator thật (tương tự khung "unified save story" của IDEA-66).

## Đề xuất
`NeonDialog`-based banner, hiện danh sách `ConsentCategory` (analytics/personalization) với nút Accept/Decline riêng từng mục (hoặc 1 cặp nút "Chấp nhận tất cả"/"Từ chối tất cả" đơn giản hơn cho MVP — cân nhắc ponytail, chọn phương án tối giản trước). Gọi thẳng `ConsentStateService.grant`/`deny`. Chỉ hiện 1 lần duy nhất — TÁI DÙNG `OnboardingCoordinatorService.registerFlow`/`isFlowSeen`/`markFlowSeen` đã có sẵn (không tự chế cờ "đã hỏi chưa" mới).

## Acceptance criteria
- [x] Accept/decline gọi đúng `ConsentStateService.grant`/`deny` cho đúng category.
- [x] Banner chỉ hiện 1 lần (dùng `OnboardingCoordinatorService`, không phải cờ tự chế mới) — gọi lại sau khi đã markFlowSeen không hiện lại nữa.
- [x] Không đổi hành vi `ConsentStateService`/`OnboardingCoordinatorService` hiện có khi không dùng banner.
- [x] Test widget verify cả accept/decline lẫn "không hiện lại lần 2".

## Quyết định

**Implementation:**
- File mới `lib/presentation/widgets/common/consent_banner.dart`: `ConsentBanner` là `StatefulWidget` bọc `child` (đúng pattern `ReviewPromptTrigger`/`AchievementUnlockListener` — wrap + tự hành động, không phải hàm `show...` độc lập, vì widget cần tự kiểm tra "đã hỏi chưa" ngay khi mount).
- `initState`: gọi `OnboardingCoordinatorService.maybe?.registerFlow(flowId, version: version)` (idempotent, an toàn gọi lại mỗi lần mount).
- `didChangeDependencies` (1 lần, guard bằng `_scheduled`): `addPostFrameCallback` gọi `_maybeShow()` — nếu `OnboardingCoordinatorService.maybe?.isFlowSeen(flowId, version)` đã true thì bỏ qua hoàn toàn, không hiện gì.
- Dialog dùng lại đúng cấu trúc `NeonDialog.show(...).then(...)` + `Completer` + `addPostFrameCallback` fallback của `confirm_dialog.dart`/`smart_review_funnel.dart` — KHÔNG viết dialog mới từ đầu. MVP tối giản (ponytail) theo đúng gợi ý trong task: 1 cặp nút "Chấp nhận tất cả"/"Từ chối tất cả" cho tất cả `ConsentCategory.values` cùng lúc, không làm UI per-category.
- Accept → `grant()` cả `analytics`+`personalization`; Decline hoặc bị dismiss (back/gesture) → `deny()` cả hai (mặc định an toàn về privacy — không mặc định thành "đã đồng ý"). Cả 2 nhánh đều gọi `markFlowSeen` để banner không lặp lại.
- Cả `ConsentStateService`/`OnboardingCoordinatorService` truy cập qua `.maybe` (null-safe, không throw nếu app chưa đăng ký service nào — cùng convention phòng thủ `AchievementUnlockListener` đã dùng).
- Thêm export vào `common_widgets.dart`, cạnh `achievement_unlock_listener.dart` (cùng nhóm "wrap child + tự trigger action").

**TDD:** file lib mới hoàn toàn → di chuyển file ra `/tmp` tạm thời (không dùng `git stash` vì file chưa từng tồn tại trong git) → chạy 6 test mới → tất cả fail đúng lý do (`Couldn't find constructor 'ConsentBanner'`, đúng vì class chưa tồn tại) → trả file lại → chạy lại pass.

**Kết quả:**
- `flutter analyze` (root): sạch.
- `flutter test --exclude-tags slow` (root): 2333 test, 19 fail — đúng khớp baseline golden-image (macOS-vs-Linux) đã biết, KHÔNG có test flaky phát sinh thêm lần chạy này, không có regression.
- Không đụng `example/` nên không cần chạy analyze/test ở đó.
- `lib/roy_casual_kit.dart` không đổi export trực tiếp (file mới chỉ qua barrel `common_widgets.dart` đã export sẵn) → không cần chạy `api_compatibility.dart`.
- Không cần device smoke test (task cho phép bỏ qua — 6 test widget verify đủ accept/decline/không-hiện-lại-2-lần/thiếu-service).

**Tự chấm điểm: 9.5/10.** Trừ 0.5 vì MVP chỉ có UI "chấp nhận/từ chối tất cả" (đúng phạm vi ponytail task yêu cầu), chưa có UI per-category chi tiết hơn cho game cần granular hơn — nằm ngoài scope MVP đã thống nhất trong chính task.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-69-consent-banner-widget.md` này trước khi làm. Đọc toàn bộ `lib/core/consent_state_service.dart`, `lib/core/onboarding_coordinator_service.dart`, VÀ `lib/presentation/widgets/common/smart_review_funnel.dart` (pattern dialog gần nhất để tái dùng) trước khi implement. Implement bằng TDD, ưu tiên phương án tối giản (ponytail) — không cần UI phức tạp per-category nếu 1 cặp nút chấp nhận/từ chối tất cả đủ dùng cho MVP.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (widget test đủ chứng minh).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — đã tự Read xác nhận đúng tên API (`grant`/`deny`/`reset`, `ConsentCategory.analytics`/`personalization`, `OnboardingCoordinatorService.registerFlow`/`isFlowSeen`/`markFlowSeen`) trước khi ghi task này (fork brainstorm gốc chỉ đoán tên, đã tự verify lại). Không trùng task nào trong `doc/task/done/`.
