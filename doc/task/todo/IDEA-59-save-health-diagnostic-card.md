---
id: IDEA-59
title: "Save-health card cho Settings/QA overlay — hiển thị lần save/flush gần nhất, trạng thái HMAC"
type: idea
priority: low
effort: S
source: "codex (độc lập)"
---

## Vị trí
Mở rộng `lib/presentation/widgets/debug_qa_overlay.dart` hoặc `example/lib/screens/settings_screen.dart`, dựa trên `lib/core/save_integrity.dart`, `lib/core/diagnostics_export_bundle.dart`.

## Hiện trạng
Không có nơi nào trong UI hiển thị "sức khoẻ" save hiện tại (lần save/flush gần nhất, HMAC có hợp lệ không, kích thước save) — người chơi/QA không có cách nào tự kiểm tra nhanh mà không cần đọc log.

## Vì sao cần / Hậu quả
Hỗ trợ debug nhanh khi người chơi báo "mất tiến trình" — QA/support có thể tự kiểm tra ngay tại chỗ (lần save cuối là khi nào, save có toàn vẹn không) mà không cần lấy log từ dev.

## Đề xuất
Thêm 1 card nhỏ hiển thị: thời điểm save/flush gần nhất, kết quả verify HMAC gần nhất (hợp lệ/lỗi), kích thước save hiện tại.

## Acceptance criteria
- [ ] Card hiển thị đúng 3 thông tin trên, cập nhật khi có save mới.
- [ ] Không ảnh hưởng hiệu năng save thật (chỉ đọc, không thêm write mới).
- [ ] Test widget cho card.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-59-save-health-diagnostic-card.md` này trước khi làm. Đọc toàn bộ `lib/core/save_integrity.dart` và `lib/presentation/widgets/debug_qa_overlay.dart` trước khi thêm card. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Không cần smoke test device bắt buộc.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng UI tiện lợi hợp lý, giá trị thấp/vừa. Không trùng task nào trong `doc/task/done/`.
