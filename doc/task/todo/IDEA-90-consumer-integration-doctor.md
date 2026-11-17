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
