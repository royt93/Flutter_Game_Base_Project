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
