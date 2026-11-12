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

## Kết quả (2026-11-12)
Thêm mục `## 5b` vào `doc/INTEGRATION_GUIDE.md` cho đủ bảy service: định nghĩa, cách đăng ký thủ công, snippet ngắn, lưu ý `Get.reset` ở `tearDown`. Nội dung bản nháp do fork soạn nhưng ba chỗ nó ghi "chưa xác nhận" (tham số `enqueue`, `uploader`, `registerParticipant`/`requestCheckpoint`, `preview`/`executePlan`) đã đối chiếu với chữ ký trong code. Sáu snippet được dán vào một test tạm: lần đầu lộ lỗi `StorageService` cần `SharedPreferences` (lỗi ở test, đã sửa), sau đó biên dịch và chạy xanh; test tạm đã xoá. Snippet `RewardTransactionPipeline` không chạy thử, chỉ trỏ tới ví dụ trong `widget_showcase_screen.dart` (cần ví và kho đồ dựng sẵn).

## Tiêu chí xong
Guide nhắc cả bảy service với ví dụ chạy được hoặc trỏ tới file example cụ thể.
