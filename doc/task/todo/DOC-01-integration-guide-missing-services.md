---
id: DOC-01
title: "INTEGRATION_GUIDE thiếu bảy service đã có test và dùng trong example"
type: doc
layer: doc/INTEGRATION_GUIDE.md
priority: P3
effort: S
source: "Scan SDK 2026-11-12 (grep 0 lần trong guide 223 dòng)"
---

## Thiếu
`OfflineOutboxService`, `RewardTransactionPipeline`, `PersistentCooldownService`, `ConsentStateService`, `AppSessionTracker`, `CheckpointCoordinator`, `GameTimeController`. Cả bảy đều có test và xuất hiện trong `example/lib`.

## Phạm vi
Mỗi service một đoạn ngắn: dùng để làm gì, đăng ký thế nào (`Get.put` hay module bootstrap), ví dụ tối thiểu lấy từ `example/lib`, lưu ý reset trong test. Không bịa hành vi: đọc code và test từng service trước khi viết.

## Tiêu chí xong
Guide nhắc cả bảy service với ví dụ chạy được hoặc trỏ tới file example cụ thể.
