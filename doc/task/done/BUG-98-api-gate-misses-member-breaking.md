---
id: BUG-98
title: "API gate bỏ sót breaking ở member"
type: bug
priority: P1
effort: M
source: "fork audit core + verify phiên chính"
---

## Vị trí

`tool/api_compatibility.dart:62-101`.

## Hiện trạng

Snapshot chỉ class/top-level symbol (`EconomyWallet`, `VersionedJsonStore`). Xóa/đổi `EconomyWallet.earn`, `VersionedJsonStore.syncWith`, constructor param vẫn báo unchanged.

## Vì sao cần / Hậu quả

Public API break âm thầm mà CI vẫn xanh.

## Đề xuất

Snapshot member signature (method/param list) cho class export; check fail khi member đổi/xóa. Không trùng BUG-80 (top-level/modern declarations).

## Acceptance criteria

- [ ] Fixture class `Foo` có method → xóa method → check fail.
- [ ] Đổi param/return type cũng fail.
- [ ] Không false positive cho private/internal member.

## Quyết định

_(điền sau khi implement + push: implementation, TDD, kết quả analyze/test, tự chấm điểm)_

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)

Đọc kỹ file task này trước khi làm. Đọc toàn bộ file source liên quan trước khi thiết kế. Implement bằng TDD.
Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test + integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ `example/`.
4. Smoke test trên device Android thật có bằng chứng (khi task đổi hành vi quan sát được).
Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.
Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, commit + push lần hai.

## Ghi chú độ tin cậy

Cao. Đã verify regex class/top-level dòng 62-101, không có member signature; BUG-80 file khác scope top-level.
