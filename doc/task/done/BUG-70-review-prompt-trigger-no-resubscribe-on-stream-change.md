---
id: BUG-70
title: "ReviewPromptTrigger không resubscribe khi widget.winStreakEvents đổi reference"
type: bug
priority: P2
effort: S
source: "claude (fork audit, độc lập) — phát hiện qua đối chiếu trực tiếp với screen_shake.dart cùng session"
---

## Vị trí
`lib/presentation/widgets/common/review_prompt_trigger.dart:67-98` (`_ReviewPromptTriggerState`).

## Hiện trạng
`initState()` subscribe `widget.winStreakEvents` đúng 1 lần duy nhất. Không có override `didUpdateWidget` nào trong class này. So sánh: `screen_shake.dart`'s `_ScreenShakeState` (cùng file dạng "wrap 1 Stream/Listenable qua constructor", viết cùng session) CÓ đúng `didUpdateWidget` để resubscribe khi `controller` đổi reference — `ReviewPromptTrigger` thiếu chính pattern này.

## Vì sao cần / Hậu quả
Nếu widget cha rebuild `ReviewPromptTrigger` với 1 `Stream<int>` KHÁC (ví dụ đổi game mode, tạo `StreamController` mới cho 1 luồng win-streak khác), `_subscription` vẫn trỏ vào stream CŨ mãi mãi — mọi event trên stream mới bị bỏ lỡ hoàn toàn, im lặng không lỗi, không log. Người dùng kit sẽ không hiểu vì sao review prompt không bao giờ kích hoạt sau khi đổi stream.

## Đề xuất
Thêm `didUpdateWidget(covariant ReviewPromptTrigger oldWidget)`: nếu `widget.winStreakEvents != oldWidget.winStreakEvents`, cancel subscription cũ rồi subscribe lại stream mới — đúng pattern `_ScreenShakeState.didUpdateWidget` đã có sẵn trong cùng thư mục.

## Acceptance criteria
- [x] Đổi `winStreakEvents` sang 1 `StreamController` khác giữa 2 lần build (`tester.pumpWidget` lại với stream mới) → event bắn trên stream MỚI vẫn được nhận đúng (gọi `maybeRequestReview`/`showReview` như thiết kế).
- [x] Stream CŨ không còn được lắng nghe nữa sau khi đổi (event bắn trên stream cũ sau đó không có tác dụng gì — không leak subscription).
- [x] Không đổi hành vi khi `winStreakEvents` không đổi qua các lần rebuild (case phổ biến nhất, phải giữ nguyên).
- [x] Test widget verify bằng 2 `StreamController<int>` riêng biệt.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-70-review-prompt-trigger-no-resubscribe-on-stream-change.md` này trước khi làm. Đọc toàn bộ `lib/presentation/widgets/common/review_prompt_trigger.dart` VÀ `lib/presentation/widgets/common/screen_shake.dart` (đối chiếu đúng cách `_ScreenShakeState.didUpdateWidget` đã làm) trước khi sửa. Implement bằng TDD — viết test trước, xác nhận fail trên code cũ (event trên stream mới bị bỏ lỡ), rồi mới sửa.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (widget test đủ chứng minh).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — đã tự Read trực tiếp cả 2 file (`review_prompt_trigger.dart`, `screen_shake.dart`), xác nhận thiếu `didUpdateWidget` là thật, có tiền lệ pattern đối chiếu ngay trong cùng thư mục/session. Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Implement**: thêm `didUpdateWidget(covariant ReviewPromptTrigger oldWidget)`
vào `_ReviewPromptTriggerState` — so sánh `oldWidget.winStreakEvents !=
widget.winStreakEvents`, nếu khác thì cancel subscription cũ + subscribe
lại stream mới. Đúng 1-1 pattern `ScreenShakeState.didUpdateWidget` đã có
sẵn (copy cấu trúc, không phát minh cách khác).

**TDD**: viết 2 test trước, `git stash` riêng `review_prompt_trigger.dart`,
chạy → test 1 FAIL ĐÚNG như dự đoán (expected 0 lần gọi `showReview` từ
stream cũ, actual 1 — chứng minh code cũ VẪN lắng nghe stream cũ sau khi
đổi), test 2 (case không đổi stream) pass bình thường trên cả code cũ
lẫn mới (đúng — case không bị ảnh hưởng bởi bug). Khôi phục, chạy lại —
9/9 pass toàn file (7 test cũ + 2 mới).

**Kết quả**: `flutter analyze` sạch cả root lẫn `example/`. `flutter test
--exclude-tags slow` root: 2313 test (+2 đúng số test mới), 20 fail — 19
golden-image + 1 flaky KHÁC lần này (`energy_service_test.dart` BUG-19
"ghi atomic" — không liên quan `review_prompt_trigger.dart`, chạy lại
riêng file đó PASS ngay, xác nhận đúng flaky không phải regression).
`example/`: 144/144 pass (`ReviewPromptTrigger` CÓ được dùng thật trong
`WidgetShowcaseScreen`, xác nhận không phá demo có sẵn). `dart run
tool/api_compatibility.dart check` → `unchanged` (chỉ thêm 1 method
lifecycle override, không đổi public API/constructor). Không cần smoke
test device (task tự ghi optional, widget test đủ chứng minh).

Tự chấm: **9.5/10** — bug thật, root cause rõ ràng, fix đúng 1-1 theo
tiền lệ có sẵn ngay trong cùng thư mục (không cần thiết kế mới), TDD
chứng minh chính xác hành vi cũ VÀ hành vi mới đúng như acceptance
criteria yêu cầu. Trừ 0.5 vì đây là bug đã tồn tại từ lúc `ReviewPromptTrigger`
được viết (ENH-87) — lẽ ra nên đối chiếu với `screen_shake.dart` (cùng
session, viết gần nhau) ngay từ lúc implement ban đầu.
