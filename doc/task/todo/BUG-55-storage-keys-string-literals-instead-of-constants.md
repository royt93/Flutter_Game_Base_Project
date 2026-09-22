---
id: BUG-55
title: "9 service dùng string literal làm default storage key thay vì hằng số StorageKeys — vi phạm convention của chính CLAUDE.md"
type: bug
priority: P2
effort: M
source: "agy + claude (độc lập xác nhận cùng vấn đề, danh sách file hơi khác nhau — gộp), verify lại qua grep 1 vài file đại diện"
---

## Vị trí
`lib/core/checkpoint_coordinator.dart` (`storageKey ?? 'checkpoint_coordinator_v1'`), `lib/core/economy_wallet.dart`, `lib/core/offline_outbox_service.dart` (`'offline_outbox_v1'`), `lib/core/inventory_service.dart`, `lib/core/player_progression_service.dart` (`'player_progression_v1'`), `lib/core/reward_transaction_pipeline.dart` (`'reward_transaction_pipeline_v1'`), `lib/core/save_slot_manager.dart` (`'save_slot_meta_v1'`), và các service tương tự.

## Hiện trạng
CLAUDE.md quy định rõ: "Never use string literals for prefs keys — add a new named constant instead." Nhưng nhiều service mới hơn (thường có tham số `storageKey` override được) dùng default value là 1 string literal trực tiếp trong constructor, thay vì tham chiếu 1 hằng số trong `StorageKeys`.

## Vì sao cần / Hậu quả
Vì key có thể override qua constructor nên KHÔNG phải bug chức năng — nhưng khiến 1 audit tương lai chỉ `grep StorageKeys` sẽ bỏ sót các key thật đang tồn tại trên máy người dùng, gây rủi ro khi cần đổi tên key hàng loạt, viết migration, hoặc rà soát toàn bộ key đang dùng của app.

## Đề xuất
Thêm hằng số tương ứng vào `StorageKeys` cho mỗi default key literal ở các file trên, dùng hằng số đó làm default value thay vì string literal trực tiếp — không đổi hành vi (default value giữ nguyên chuỗi cũ để tương thích ngược với data đã lưu trên máy người dùng).

## Acceptance criteria
- [ ] Mọi service liệt kê ở "Vị trí" dùng hằng số `StorageKeys.*` làm default storage key, không còn string literal trực tiếp trong constructor.
- [ ] Giá trị chuỗi thật của mỗi hằng số GIỮ NGUYÊN y hệt string literal cũ (không đổi key thật — tránh mất dữ liệu người dùng đã lưu).
- [ ] `grep -rn "StorageKeys\." lib/core/*.dart | wc -l` tăng đúng số lượng constant mới thêm; `grep` các default key literal cũ không còn kết quả nào trong `lib/core/`.
- [ ] Test hiện có của toàn bộ các service trên vẫn pass nguyên vẹn (key thật không đổi).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-55-storage-keys-string-literals-instead-of-constants.md` này trước khi làm. Đọc toàn bộ `lib/core/storage_service.dart` (class `StorageKeys`) và từng file liệt kê ở "Vị trí" trước khi sửa — xác nhận đúng chuỗi literal thật đang dùng ở mỗi file (đừng suy đoán, tự grep lại). Implement bằng TDD nếu hợp lý (test đảm bảo key thật không đổi), tuy đây chủ yếu là refactor cơ học.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung/verify test cho MỌI case ở Acceptance criteria (đặc biệt: key thật không đổi giá trị).
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Không cần smoke test device bắt buộc (refactor cơ học, không đổi hành vi/UI quan sát được — nhưng khuyến khích 1 lần cài đè bản cũ lên bản mới để verify dữ liệu người dùng cũ vẫn đọc được đúng, nếu tiện).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — 2 nguồn độc lập (agy, claude) cùng nêu vấn đề, danh sách file gần trùng nhau; đã grep xác nhận 1 vài default key literal tồn tại đúng như mô tả (`'offline_outbox_v1'`, `'reward_transaction_pipeline_v1'`, `'player_progression_v1'` — xác nhận qua Read constructor ở BUG-40). Đây là vi phạm convention (P2), không phải bug chức năng — effort M vì cần rà soát cẩn thận để KHÔNG đổi giá trị chuỗi thật (tránh mất data người dùng). Không trùng task nào trong `doc/task/done/`.
