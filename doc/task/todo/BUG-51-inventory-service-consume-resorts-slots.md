---
id: BUG-51
title: "InventoryService.consume tự sort lại toàn bộ hòm đồ theo slotId, phá vỡ sắp xếp thủ công của người chơi"
type: bug
priority: P1
effort: S
source: "agy (độc lập), verify lại qua Read lib/core/inventory_service.dart (khu vực consume, ~dòng 285-320)"
---

## Vị trí
`lib/core/inventory_service.dart` — `consume()`, ~dòng 285-320.

## Hiện trạng
Khi tiêu 1 vật phẩm, code tạo `scratch = [..._slots]..sort((a, b) => a.slotId.compareTo(b.slotId))` rồi gán lại `_slots = scratch` — sắp xếp lại TOÀN BỘ danh sách slot theo `slotId` mỗi lần consume, bất kể người chơi đã tự sắp xếp lại (kéo-thả) hòm đồ theo thứ tự khác trước đó.

## Vì sao cần / Hậu quả
Người chơi kéo-thả sắp xếp hòm đồ theo ý muốn (ví dụ nhóm vật phẩm theo loại), rồi tiêu 1 vật phẩm bất kỳ — toàn bộ sắp xếp bị reset về thứ tự `slotId` mặc định, mất công sức tổ chức hòm đồ của người chơi, trải nghiệm khó chịu và không nhất quán với `InventoryGrid` (widget hỗ trợ kéo-thả đổi chỗ).

## Đề xuất
`consume()` chỉ cần tìm và giảm/xoá đúng slot chứa item bị tiêu — không cần sort lại toàn bộ danh sách. Nếu việc sort có lý do khác (ví dụ đảm bảo bất biến nội bộ nào đó), thay bằng thao tác tại chỗ (in-place update đúng index) thay vì rebuild + sort toàn bộ.

## Acceptance criteria
- [ ] Sắp xếp hòm đồ theo thứ tự tuỳ ý (không theo `slotId`), gọi `consume()` 1 item — thứ tự các slot KHÁC không đổi.
- [ ] `consume()` vẫn giảm đúng số lượng/xoá đúng slot chứa item bị tiêu.
- [ ] Test hiện có của `inventory_service_test.dart` vẫn pass.
- [ ] Test mới: verify thứ tự slot giữ nguyên sau `consume()` khi thứ tự ban đầu không phải thứ tự `slotId`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-51-inventory-service-consume-resorts-slots.md` này trước khi làm. Đọc toàn bộ `lib/core/inventory_service.dart` (đặc biệt `grant`/`consume`/cấu trúc `_slots`) và test hiện có trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test (nếu có `InventoryGrid` demo trong example) cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/` nếu có demo liên quan.
4. Smoke test trên device thật khuyến khích nếu `InventoryGrid` có demo tương tác kéo-thả trong example, không bắt buộc nếu chỉ là service logic thuần.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — dựa trên mô tả kỹ thuật cụ thể của agy (đoạn code trích dẫn khớp phong cách file), chưa tự Read lại dòng chính xác do khối lượng lớn của batch verify, nhưng logic mô tả (resort toàn bộ theo `slotId` mỗi lần consume) là hành vi dễ kiểm chứng/dễ sai nếu đúng — người thực hiện cần tự đọc lại đúng dòng trước khi sửa (đã ghi rõ trong Prompt). Không trùng task nào trong `doc/task/done/`.
