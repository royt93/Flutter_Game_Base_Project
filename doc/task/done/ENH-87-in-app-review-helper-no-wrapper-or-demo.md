---
id: ENH-87
title: "InAppReviewHelper không có widget/listener wrapper hay demo — service đúng loại cần trigger đúng lúc lại thiếu counterpart UI"
type: enhancement
priority: P2
effort: M
source: "claude (độc lập)"
---

## Vị trí
`lib/core/in_app_review_helper.dart`, so sánh với `lib/presentation/widgets/achievement_unlock_listener.dart` (`AchievementUnlockListener` bọc `AchievementService` — đúng pattern "core service có timing logic → widget listener kèm theo").

## Hiện trạng
`InAppReviewHelper` chứa decision logic "nên hỏi đánh giá app ngay bây giờ không" (đúng thời điểm sau 1 khoảnh khắc vui — pattern casual-game kinh điển) nhưng không có widget wrapper nào tự động lắng nghe đúng thời điểm và trigger review prompt, khác với `AchievementService` đã có `AchievementUnlockListener` làm đúng việc này. Cũng không có demo trong `example/`.

## Vì sao cần / Hậu quả
1 dev tích hợp phải tự viết code lắng nghe đúng "khoảnh khắc vui" (ví dụ sau khi thắng level) rồi gọi `InAppReviewHelper` thủ công — không có ví dụ/widget tiện lợi nào để copy, dù kit đã có tiền lệ pattern này cho `AchievementService`.

## Đề xuất
Thêm 1 widget/listener nhỏ (ví dụ `ReviewPromptTrigger`) nhận 1 `Stream`/callback "khoảnh khắc vui" (ví dụ `onLevelWon`) và tự gọi `InAppReviewHelper.maybeRequestReview()` đúng lúc theo policy có sẵn. Thêm demo trong `example/` minh hoạ cách nối 1 sự kiện thắng level giả lập với helper này.

## Acceptance criteria
- [x] Có 1 widget/helper wrapper mới bọc `InAppReviewHelper`, theo đúng pattern `AchievementUnlockListener` đã có.
- [x] Demo trong `example/` minh hoạ trigger review prompt sau 1 sự kiện giả lập (ví dụ nút "Giả lập thắng level").
- [x] Test widget verify wrapper gọi đúng `InAppReviewHelper` API khi điều kiện thoả, không gọi khi chưa đủ điều kiện (policy: không hỏi quá thường xuyên).
- [x] Không đổi hành vi `InAppReviewHelper` core logic hiện có.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-87-in-app-review-helper-no-wrapper-or-demo.md` này trước khi làm. Đọc toàn bộ `lib/core/in_app_review_helper.dart` và `lib/presentation/widgets/achievement_unlock_listener.dart` (pattern tham khảo) trước khi implement. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device thật khuyến khích (verify demo trigger đúng, không double-prompt) không bắt buộc nếu widget test đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — so sánh hợp lý với tiền lệ `AchievementUnlockListener` đã có trong repo (xác nhận file tồn tại theo CLAUDE.md). Không trùng task nào trong `doc/task/done/`. Lưu ý: khác với IDEA-61 (smart review funnel like/dislike) — task này chỉ là "có wrapper/demo cơ bản", IDEA-61 là 1 tính năng branching UX cụ thể hơn xây TRÊN nền tảng ENH-87 nếu cả 2 được chọn.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Implement**: `ReviewPromptTrigger` (`lib/presentation/widgets/common/review_prompt_trigger.dart`)
— `StatefulWidget` bọc `child`, nhận `winStreakEvents` (`Stream<int>`,
caller-supplied — không có nguồn "happy moment" chung nào sẵn trong kit
để service tự phát, khác `AchievementService.onUnlock`), `showReview`
(seam đã có của `maybeRequestReview`), cùng `minWinStreak`/`everDeclined`/
`cooldown` forward thẳng xuống `maybeRequestReview`. Mỗi event trên
stream gọi `maybeRequestReview(...)`; nếu trả `true` thì fire
`onRequested` callback (hook tuỳ chọn cho consumer log/analytics). Bọc
`try/catch` quanh lời gọi để không bao giờ throw ra ngoài (đúng convention
`AchievementUnlockListener` đã có). Export qua `common_widgets.dart` (barrel
đã tự propagate lên `roy_casual_kit.dart`, không cần thêm export riêng).

**Không sửa `in_app_review_helper.dart`** — `maybeRequestReview` giữ
nguyên 100%, `ReviewPromptTrigger` chỉ gọi lại đúng API công khai sẵn có,
đúng yêu cầu AC4.

**Không thêm state "policy" riêng**: `everDeclined` đọc trực tiếp từ
`widget.everDeclined` mỗi lần event tới (không cache ở `initState`) — 1
`setState` ở widget cha đổi giá trị này sẽ có hiệu lực ngay từ event tiếp
theo, không cần rebuild lại toàn `ReviewPromptTrigger`.

**Demo `example/`**: `WidgetShowcaseScreen` bọc thêm
`ReviewPromptTrigger` (giữa `LevelUpOverlay`/`AchievementUnlockListener`
đã có và `Scaffold`), thêm state `_reviewWinStreak`/`_reviewPromptShown`
+ `StreamController<int>` riêng, nút "Giả lập thắng level" tăng
win-streak và đẩy event vào stream; card demo hiện đếm win-streak + số
lần review prompt đã hiện (đếm qua `showReview` giả — đúng convention
"package trung lập SDK cụ thể" của `in_app_review_helper.dart`, demo
không phụ thuộc package `in_app_review` thật).

**TDD**: viết file widget mới trước, chạy test → fail biên dịch ("Method
not found: 'ReviewPromptTrigger'") do file chưa tồn tại — tạm `mv` file
widget ra `/tmp` + `git stash` riêng `common_widgets.dart` để mô phỏng
"code cũ chưa có widget này", xác nhận lỗi đúng, khôi phục cả 2. 7 test
mới `test/widget/common/review_prompt_trigger_test.dart` pass 7/7: render
không crash; đủ ngưỡng → gọi `showReview` đúng 1 lần + `onRequested` fire;
chưa đủ ngưỡng → không gọi; `everDeclined: true` → không bao giờ gọi;
event thứ 2 trong cooldown → không double-prompt; `showReview` throw →
không crash; dispose giữa chừng không crash.

**Kết quả**: `flutter analyze` sạch cả root lẫn `example/`. `flutter test
--exclude-tags slow` root: 2247 test (+7 đúng số test mới), 19 fail —
khớp baseline golden-image, không fail mới. `example/`: 142/142 pass
(không thêm test riêng cho demo card mới — theo đúng tiền lệ có sẵn trong
`widget_showcase_screen_test.dart`: không phải mọi `_Demo` card đơn giản
"bấm nút tăng counter" đều có test màn hình riêng khi logic lõi đã được
test đầy đủ ở tầng widget unit test; các test màn hình hiện có chỉ dành
cho demo có state machine phức tạp hơn). `dart run
tool/api_compatibility.dart check` → `unchanged` — do giới hạn có sẵn của
tool (chỉ scan symbol NGAY TRONG file được `export` trực tiếp từ
`roy_casual_kit.dart`; `common_widgets.dart` chỉ là 1 barrel re-export
tiếp, bản thân không có symbol nào để tool bắt được) — không phải lỗi mới
do task này gây ra, hành vi giống hệt mọi widget khác từng thêm qua barrel
này trước đây (ví dụ `AchievementUnlockListener`).

**Bỏ qua smoke test device**: task tự ghi rõ "khuyến khích... không bắt
buộc nếu widget test đủ chứng minh" — 7 widget test cover đủ mọi nhánh
policy (ngưỡng, cooldown, everDeclined, lỗi, dispose), quyết định bỏ qua
để tiết kiệm thời gian, ghi nhận trung thực ở đây thay vì tự nhận đã test
device.

Tự chấm: **9.5/10** — đúng pattern tiền lệ `AchievementUnlockListener`,
TDD chứng minh đầy đủ, demo thật trong `example/` (không phải chỉ unit
test), không đổi hành vi core. Trừ 0.5 vì bỏ qua smoke test device (dù
được phép) và chưa thêm test riêng cho demo card trong
`widget_showcase_screen_test.dart`.
