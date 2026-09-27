---
id: ENH-94
title: "Remote content pack cần durable verified cache"
type: enhancement
priority: P0
effort: M
source: "fork audit core + verify phiên chính"
---

## Vị trí

`lib/core/remote_content_pack.dart` (`RemoteContentPack.load`/`_refreshFromRemote`, toàn file); tích hợp `storage_service.dart`, `versioned_json_store.dart`.

## Hiện trạng

`_current` chỉ giữ trong RAM — `load()` luôn đọc lại asset bundle rồi mới fetch remote (dòng 79-93); một fetch thành công không được ghi xuống storage. Restart mất verified content mới nhất, quay lại asset gốc; nếu fetch tiếp theo lỗi, không còn "last known good" để dùng — chỉ còn asset fallback.

## Vì sao cần / Hậu quả

Live-ops content (level, event, shop catalog) cập nhật xong, user restart app hoặc network chập chờn thì content quay về bản asset cũ — trải nghiệm live-ops không đáng tin.

## Đề xuất

Thêm durable cache: chỉ ghi storage sau verify+migrate thành công (không ghi envelope thô). Khi `load()` chạy offline, đọc cache trước asset nếu cache mới hơn/hợp lệ. Envelope tamper/schema xấu giữ bản cache cũ. Atomic swap (ghi xong mới trỏ `_current`) + max-age tùy chọn.

## Acceptance criteria

- [ ] Fake `AssetBundle` + fake fetch: verified fetch → ghi cache → restart (instance mới) đọc cache đúng nội dung.
- [ ] Tamper envelope (đổi checksum) → cache cũ giữ nguyên, không bị ghi đè.
- [ ] Restart offline (fetch throw) → dùng cache verified gần nhất, không rơi về asset cũ hơn.
- [ ] Schema version xấu (mới hơn compiled) → giữ cache cũ.

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

Cao. Đã đọc toàn bộ `remote_content_pack.dart` (149 dòng): `_current` là field instance thuần RAM, `load`/`_refreshFromRemote` không gọi `storage`/`VersionedJsonStore` ở đâu cả — xác nhận không có persistence. Không trùng IDEA-37 (signed packs, khác file), FEAT-81 (schema compiler), FEAT-90 (shadow activation).
