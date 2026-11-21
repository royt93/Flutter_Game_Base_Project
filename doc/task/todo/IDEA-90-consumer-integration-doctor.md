---
id: IDEA-90
title: "Consumer doctor: lệnh kiểm tra app consumer tích hợp SDK đúng cách"
type: idea
layer: tool
priority: P2
effort: M
source: "Yêu cầu SDK hoàn hảo; consumer-smoke chỉ kiểm app sinh sẵn, không kiểm app thật của đối tác"
---

## Ý tưởng
`dart run roy_casual_kit:doctor` chạy trong app consumer, in báo cáo tĩnh: đã gọi `RoyCasualKit.initialize` chưa; có đăng ký `PurchaseSeam`/`CrashReporter`/`AnalyticsProvider` chưa (từng seam có `Noop` hay không); assets font Baloo2 có trong pubspec; `SystemChrome` khóa orientation (cảnh báo landscape layout chưa kiểm); khóa `StorageKeys` trùng; phiên bản SDK so với CHANGELOG (cảnh báo behavior change như ENH-103).

## Giá trị
Giảm "tích hợp sai âm thầm" mà không cần đọc README; đối tác tự chạy được.

## Làm gì trước khi bắt tay
Xác nhận nhu cầu với partner (có ai đang tích hợp thật không), vì nếu chưa có consumer thật thì chưa rõ ưu tiên.

## Trạng thái (2026-11-17): chờ xác nhận đối tác, chưa xây
Mục "Làm gì trước khi bắt tay" chưa được đáp ứng: chưa có bằng chứng một đối tác đang tích hợp thật. Người dùng chọn giữ task ở trạng thái chờ thay vì xây bản thu gọn (lệnh `doctor` là bề mặt CLI công khai mới). Mở lại khi có đối tác xác nhận nhu cầu; bản thu gọn khả thi là các kiểm tra tĩnh rẻ (đã gọi `RoyCasualKit.initialize`, font Baloo2 trong pubspec, khoá orientation, seam còn `Noop`).

## Kết luận khi đọc mã (2026-11-17, người dùng chọn: không xây)

## Prompt loop

Không triển khai khi chưa có partner xác nhận use case; trạng thái hiện tại là **không xây** theo quyết định 2026-11-17. Nếu owner mở lại sau partner validation, kiểm tra trước xem `consumer-smoke`/`tool/create_consumer_app.dart` đã phủ gap chưa; chỉ đề xuất runtime diagnostic khi còn gap thực. Hỏi owner trước mọi API/public-contract change. Nếu được duyệt, viết unit tests cho misconfiguration, valid optional seams và false positives; chạy analyze/API compatibility và consumer integration tests phù hợp. Physical-device smoke chỉ khi runtime/platform behavior đổi, dùng device thật, không simulator. Audit code changes và chấm >9/10; nếu mọi gate đạt thì push code theo yêu cầu. Dừng nếu partner validation thiếu, test fail, device proof áp dụng không có, hoặc score <=9.

## Acceptance criteria

- [ ] Partner xác nhận use case cụ thể; nếu chưa, giữ nguyên quyết định không xây.
- [ ] Chứng minh consumer-smoke hiện có chưa đáp ứng gap trước khi thêm diagnostic.
- [ ] False-positive tests bao phủ optional/no-op seams được chủ ý chọn.
- [ ] API snapshot/CHANGELOG cập nhật nếu có public API.
- [ ] Ghi test/device evidence phù hợp, score >9/10 và chỉ push code khi mọi gate pass.

## Kết quả thực hiện

- Partner validation / owner decision:
- Audit score / rubric:
- Tests:
- Device smoke (nếu áp dụng):
- Commit/push:
- Blockers/rủi ro:
Hai trong bốn kiểm tra của ý tưởng gốc không chạy được: (1) font Baloo2 do package tự đóng gói (`NeonTheme.fontFamily = 'packages/roy_casual_kit/Baloo2'`), consumer không phải khai báo; (2) seam `PurchaseSeam`/`CrashReporter`/`AnalyticsProvider` đăng ký lúc chạy bằng `Get.put`, phân tích tĩnh không đọc được. Còn đứng được: có gọi `RoyCasualKit.initialize`, có phụ thuộc `roy_casual_kit`, khoá orientation; ba mục này gần như đã được `consumer-smoke` và `tool/create_consumer_app.dart` phủ. Nếu mở lại, hướng ít dương tính giả hơn là hàm runtime gọi sau `initialize` báo seam nào còn `Noop` hoặc chưa đăng ký (là API công khai mới: cần snapshot và CHANGELOG), và chỉ khi có đối tác xác nhận nhu cầu.
