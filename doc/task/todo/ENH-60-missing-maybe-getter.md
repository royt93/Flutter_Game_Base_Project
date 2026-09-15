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
- [ ] `EconomyWallet.maybe` trả `null` khi chưa `Get.put`, trả đúng instance khi đã đăng ký.
- [ ] `RoyLifecycleCoordinator.maybe` trả `null` khi chưa `Get.put`, trả đúng instance khi đã đăng ký.
- [ ] Không phá bất kỳ test/API hiện có nào.
- [ ] Test: cả 2 case (chưa đăng ký / đã đăng ký) cho mỗi class — unit test đơn giản, giống hệt các test `.maybe` đã có cho service khác.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Không cần device smoke test (pure logic, không có UI).

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
