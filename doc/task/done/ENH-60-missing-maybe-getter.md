---
id: ENH-60
title: "EconomyWallet/RoyLifecycleCoordinator thiếu static .maybe getter"
type: enhancement
priority: P2
effort: S
source: Claude (self-generated backlog brainstorm đợt 2 — xác nhận qua grep trực tiếp, không phỏng đoán)
---

## User story
Là dev dùng kit, tôi muốn mọi `GetxService` trong `lib/core/` đều có cách kiểm tra an toàn "đã đăng ký chưa" (`X.maybe`) giống hệt nhau, để viết code/test không phải nhớ ngoại lệ nào có, ngoại lệ nào không.

## Hiện trạng và bằng chứng
`grep -n "static.*maybe" lib/core/*.dart` xác nhận MỌI `GetxService` khác trong `lib/core/` đều có static getter `X.maybe` (ví dụ `PurchaseLedgerService.maybe`, `LocalScoreboardService.maybe`, `AchievementService.maybe`, `DailyQuestService.maybe`, `SeasonEventService.maybe`...) — TRỪ đúng 2 file: `lib/core/economy_wallet.dart` (`class EconomyWallet extends GetxService`) và `lib/core/lifecycle_coordinator.dart` (`class RoyLifecycleCoordinator extends GetxService with WidgetsBindingObserver`). Đây đúng hình dạng gap đã từng được sửa ở ENH-19 ("CloudSaveProvider là seam duy nhất thiếu .maybe") — 2 file này được thêm SAU ENH-19 nên lọt lưới.

## Scope
- Thêm `static EconomyWallet? get maybe => Get.isRegistered<EconomyWallet>() ? Get.find<EconomyWallet>() : null;` vào `EconomyWallet`.
- Thêm tương tự cho `RoyLifecycleCoordinator`.
- Không đổi bất kỳ hành vi nào khác — chỉ thêm 1 getter mỗi class, đúng convention đã có sẵn ở mọi service khác (copy nguyên xi pattern, không tự sáng tạo cách khác).

## Acceptance criteria
- [x] `EconomyWallet.maybe` trả `null` khi chưa `Get.put`, trả đúng instance khi đã đăng ký.
- [x] `RoyLifecycleCoordinator.maybe` trả `null` khi chưa `Get.put`, trả đúng instance khi đã đăng ký.
- [x] Không phá bất kỳ test/API hiện có nào.
- [x] Test: cả 2 case (chưa đăng ký / đã đăng ký) cho mỗi class — unit test đơn giản, giống hệt các test `.maybe` đã có cho service khác.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Không cần device smoke test (pure logic, không có UI).

## Quyết định

Implement đúng phần Scope — copy nguyên xi pattern `.maybe` đã có (ví dụ `LocalScoreboardService.maybe`) vào `EconomyWallet` (`lib/core/economy_wallet.dart`) và `RoyLifecycleCoordinator` (`lib/core/lifecycle_coordinator.dart`), cùng doc comment "Gets the instance if already registered (safe to call from game/widget tests)." Không có gì cần quyết định thêm — task nhỏ, đúng y hệt 1 pattern đã lặp lại nhiều lần trong codebase.

**Test:** thêm nhóm "ENH-60: .maybe" (2 test/class — chưa đăng ký trả `null`, đã đăng ký trả đúng instance) vào `test/core/economy_wallet_test.dart` và `test/core/lifecycle_coordinator_test.dart`.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1004/1004 pass; `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 46/46 pass (không đụng `example/`). CHANGELOG.md đã thêm mục dưới `## 0.2.0`. `tool/api_compatibility.dart snapshot` chạy lại KHÔNG tạo diff — 2 getter mới chỉ là member trên class đã export sẵn, cùng tiền lệ đã ghi nhận nhiều lần (IDEA-35/43/44/45, ENH-59).

**Tự chấm điểm: 10/10** — đúng yêu cầu Scope, không thêm gì thừa, test đầy đủ, không phá gì, không có gì cần cân nhắc/đánh đổi (task đơn giản nhất trong toàn bộ backlog tự sinh tới giờ).

## Prompt loop implementation
Đọc kỹ file `doc/task/todo/ENH-60-missing-maybe-getter.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Scope bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — chỉ thêm đúng 2 getter, không thêm gì khác).
2. Bổ sung ĐỦ test cho MỌI case liên quan.
3. Không có UI/animation liên quan — N/A.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Không cần device smoke test (pure logic).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.
