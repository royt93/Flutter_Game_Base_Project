---
id: IDEA-57
title: "ExperimentBucketingService chưa có demo trong widget_showcase_screen.dart"
type: idea
priority: low
effort: S
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `example/lib/screens/widget_showcase_screen.dart`)
---

## Vị trí
Mở rộng — `example/lib/screens/widget_showcase_screen.dart`.

## Hiện trạng
`ExperimentBucketingService` (`lib/core/experiment_bucketing_service.dart`) không có usage nào trong `example/lib/` — không tìm thấy import/`Get.put`/gọi `variantFor` ở bất kỳ đâu trong demo app. Ngược lại, các core service khác cùng "tầng" (không có widget riêng, chỉ là logic thuần) đều đã có demo minh hoạ trong `widget_showcase_screen.dart`: `LocalScoreboardService` (IDEA-46, dòng ~340), `PurchaseLedgerService` (IDEA-47, dòng ~348), `AchievementService`, `OnboardingCoordinatorService` (IDEA-54), `SaveSlotManager` (IDEA-56).

## Vì sao cần / Hậu quả
`example/` là nơi 1 dev tích hợp package này lần đầu tham khảo cách dùng từng service — thiếu demo cho `ExperimentBucketingService` nghĩa là service này (dù đã có unit test đầy đủ) không có ví dụ sử dụng thực tế nào để copy. Giá trị thấp hơn 3 task ENH-75/76/77 (chỉ đụng `example/`, không phải tính năng package), nhưng vẫn là gap thật trong tính đầy đủ của demo app.

## Đề xuất
Thêm 1 `_Demo` section nhỏ trong `_WidgetShowcaseScreenState`, theo đúng convention `.maybe ?? Get.put(...)` đã dùng cho mọi service khác trong file này:

```dart
late final ExperimentBucketingService _experiments;
```

Trong `initState`:
```dart
_experiments =
    ExperimentBucketingService.maybe ??
    Get.put(ExperimentBucketingService(), permanent: true);
```

Trong `build`, thêm 1 `_Demo` hiển thị variant được gán cho 1 experiment mẫu (ví dụ `'cta_color_test'` với 3 variant `['control', 'blue', 'gold']`) và `anonymousId` (rút gọn, ví dụ 8 ký tự đầu) — không cần nút "re-roll" vì đúng điểm mấu chốt của service là kết quả ỔN ĐỊNH qua mỗi lần build/restart, không phải random mỗi lần gọi.

## Acceptance criteria
- [x] `ExperimentBucketingService` được `Get.put` đúng convention `.maybe ?? Get.put(..., permanent: true)`.
- [x] Demo hiển thị đúng variant trả về từ `variantFor` cho 1 experiment key cố định.
- [x] Gọi lại `variantFor` cùng key nhiều lần (ví dụ qua `setState` rebuild) vẫn trả đúng y hệt variant cũ (đúng tính ổn định của service, không phải giả lập).
- [x] Không đổi hành vi bất kỳ demo/service nào khác trong `widget_showcase_screen.dart`.
- [x] Không phá bất kỳ widget test nào trong `example/test/`.
- [x] Test: widget test cho demo section mới trong `example/test/` (verify hiển thị đúng, không throw).
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch trong `example/` (chạy từ `cd example`).
- [x] Không bắt buộc đụng root `lib/`/`test/` (task này chỉ ở `example/`).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-57-wire-experiment-bucketing-demo.md` này trước khi làm. Đọc `lib/core/experiment_bucketing_service.dart` toàn bộ (đặc biệt `variantFor`/`anonymousId`) và đọc `example/lib/screens/widget_showcase_screen.dart` — tìm chính xác cách `PurchaseLedgerService`/`SaveSlotManager` được khởi tạo (`.maybe ?? Get.put`) và cách 1 `_Demo` section được thêm vào `build()` — trước khi sửa. Implement bằng TDD (viết test fail trước, code cho pass) trong `example/test/`.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng nhất quán với convention `.maybe ?? Get.put` đã dùng cho mọi service khác trong file này, không over-engineer — không thêm nút re-roll giả tạo, không tự bịa i18n).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria trong `example/test/`.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch TRONG `example/` (từ `cd example`), và verify root `flutter analyze`/`flutter test --exclude-tags slow` vẫn sạch (không đụng root nhưng verify không phá gì).
4. Không cần device smoke test bắt buộc (chỉ hiển thị text tĩnh, không có tương tác phức tạp) nhưng khuyến khích nếu tiện.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — xác nhận qua `grep -rn ExperimentBucketingService example/lib/` không có kết quả nào, trong khi service này tồn tại đầy đủ ở `lib/core/experiment_bucketing_service.dart` với unit test riêng. Xác nhận convention `.maybe ?? Get.put(..., permanent: true)` là pattern nhất quán đã dùng cho MỌI service khác trong `widget_showcase_screen.dart` (không phải suy đoán). Giá trị thấp nhất trong 4 task được chọn ở vòng brainstorm này (chỉ đụng `example/`, không phải tính năng package thật) — người dùng đã tự chọn biết rõ điều này qua mô tả option khi pick. Không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có trong `doc/task/done/`.

## Quyết định

Đúng như đề xuất — `_experiments` khởi tạo qua `.maybe ?? Get.put(..., permanent: true)` đúng convention. Demo hiển thị variant cho experiment mẫu `'cta_color_test'` (3 variant `control`/`blue`/`gold`) + 8 ký tự đầu của `anonymousId`. Không thêm nút re-roll — đúng điểm mấu chốt của service là kết quả ổn định.

**Test:** 1 test mới trong `example/test/widget_showcase_screen_test.dart` — verify hiển thị đúng, verify variant KHÔNG đổi sau khi trigger 1 `setState` không liên quan (tạo save slot), chứng minh tính ổn định thật (không phải giả lập).

**Kết quả:** `example/` `flutter analyze` sạch, `flutter test --exclude-tags slow` 55/55 pass. Root `flutter analyze`/`flutter test --exclude-tags slow` verify vẫn sạch, 1259/1259 pass (không đụng root).

**Tự chấm điểm: 9/10** — đúng convention có sẵn, test verify đúng tính ổn định (không chỉ verify hiển thị tĩnh). Trừ 1 vì đây là task giá trị thấp nhất trong 4 task được chọn (chỉ đụng demo app, không phải tính năng package thật).
