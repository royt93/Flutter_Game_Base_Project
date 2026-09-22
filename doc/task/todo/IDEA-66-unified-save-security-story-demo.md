---
id: IDEA-66
title: "Demo/doc hoá luồng đầy đủ 'load → verify HMAC → migrate N version → sync cloud' — 3 mảnh đã có nhưng chưa từng ghép chung"
type: idea
priority: low
effort: L
source: "claude (độc lập)"
---

## Vị trí
`lib/core/save_migration_registry.dart`, `lib/core/save_integrity.dart`, `lib/core/cloud_save_provider.dart` (seam) + `lib/core/versioned_json_store.dart`.

## Hiện trạng
`SaveMigrationRegistry` + `SaveIntegrityService` (HMAC) + `CloudSaveProvider` seam đều tồn tại độc lập, mỗi cái làm đúng 1 việc (đúng tinh thần thiết kế của kit), nhưng không có service/doc/demo nào minh hoạ luồng đầy đủ: load save → verify HMAC → nếu cần, chạy qua N bước migration → sync lên cloud → xử lý conflict nếu có.

## Vì sao cần / Hậu quả
Đa số game-kit khác không có cả 3 mảnh này cùng lúc — ghép chúng thành 1 flow tài liệu hoá + demo rõ ràng là lợi thế cạnh tranh thật (differentiator), không phải tính năng phổ biến, nhưng hiện tại giá trị này "ẩn" vì không đâu chứng minh chúng hoạt động cùng nhau.

## Đề xuất
Viết 1 phần trong README/CLAUDE.md + 1 demo trong `example/` (có thể là 1 màn hình mới hoặc mở rộng `CookbookScreen`) minh hoạ đầy đủ chuỗi: khởi tạo save cũ (version thấp) → verify HMAC → migrate qua `SaveMigrationRegistry` → sync qua 1 `CloudSaveProvider` fake → xử lý 1 tình huống conflict giả lập.

## Acceptance criteria
- [ ] Demo minh hoạ đủ 4 bước (load/verify/migrate/sync) trong 1 luồng liên tục, không phải 4 demo rời rạc.
- [ ] README/CLAUDE.md có 1 đoạn giải thích rõ đây là 1 tổ hợp differentiator, không phải 4 tính năng riêng lẻ.
- [ ] Test widget/integration cho demo minh hoạ đủ luồng.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-66-unified-save-security-story-demo.md` này trước khi làm. Đọc toàn bộ `lib/core/save_migration_registry.dart`, `lib/core/save_integrity.dart`, `lib/core/cloud_save_provider.dart`, `lib/core/versioned_json_store.dart` trước khi thiết kế demo. Implement bằng TDD cho phần code, cân nhắc kỹ effort L — có thể chia nhỏ thành demo tối thiểu trước, mở rộng sau nếu cần.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget/integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device thật khuyến khích (chạy hết luồng demo, verify từng bước) không bắt buộc nếu widget test đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng hợp lý về mặt "storytelling"/documentation, dựa trên 3 hạ tầng đã có thật; effort L thực ra chủ yếu là công sức viết demo/doc chứ không phải code mới phức tạp. Không trùng task nào trong `doc/task/done/`.
