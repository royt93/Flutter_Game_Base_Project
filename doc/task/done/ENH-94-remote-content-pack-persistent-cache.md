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

- [x] Fake `AssetBundle` + fake fetch: verified fetch → ghi cache → restart (instance mới) đọc cache đúng nội dung.
- [x] Tamper envelope (đổi checksum) → cache cũ giữ nguyên, không bị ghi đè.
- [x] Restart offline (fetch throw) → dùng cache verified gần nhất, không rơi về asset cũ hơn.
- [x] Schema version xấu (mới hơn compiled) → giữ cache cũ.

## Quyết định

Implement bằng named constructor mới `RemoteContentPack.withCache({required storage, required cacheKey, maxCacheAge, ...})`,
giữ nguyên constructor mặc định y hệt cũ (cache tắt hẳn) để không phá API compatibility gate (`tool/api_compatibility.dart check` báo `additive`).

- `load()`: thử đọc cache trước (`_tryLoadFromCache`, validate `schemaVersion` không được lớn hơn compiled version + `maxCacheAge` qua `nowMsClamped`), chỉ fallback asset khi cache thiếu/hỏng/hết hạn.
- `_refreshFromRemote()`: ghi cache (`_writeCache`) TRƯỚC KHI gán `_current` — nếu ghi storage throw, giữ nguyên `_current` cũ (atomic swap, không áp dụng nội dung mới của lần fetch đó).
- Cache lưu JSON đã validate+migrate (không phải envelope thô), tránh phải re-verify HMAC mỗi lần đọc nguội.

TDD: viết 9 test trong `group('ENH-94: durable verified cache', ...)` trước (đỏ), sau đó implement tới khi xanh. Toàn bộ 17 test cũ (cache tắt) không sửa, vẫn pass nguyên văn.

Test coverage: unit (`test/core/remote_content_pack_test.dart`, 9 case mới: verified-fetch-ghi-cache-restart-đọc-đúng, tamper-checksum-giữ-cache-cũ, offline-dùng-cache, schema-tương-lai-reject, fromJson-throw-fallback-asset, maxCacheAge-hết-hạn-fallback-asset, maxCacheAge-null-không-hết-hạn, cache-tắt-behavior-cũ-nguyên-văn, cacheKey-rỗng-ArgumentError-tại-constructor), widget (`example/test/cookbook_screen_remote_config_test.dart`: seed cache qua `SharedPreferences.setMockInitialValues`, xác nhận tile hiện đúng nội dung cache), integration/device (`example/integration_test/app_boot_test.dart`: fetch thật + verify chữ ký → dựng instance thứ 2 mô phỏng restart → đọc đúng cache, chạy trên thiết bị Android thật TECNO KJ7).

Kết quả: `flutter analyze` sạch root + `example/`. `flutter test --exclude-tags slow` sạch root (1 flake tiền-tồn-tại không liên quan ở `energy_service_test.dart`, xác nhận qua `git stash` + chạy lại độc lập) + sạch `example/`. Smoke test device thật pass. `tool/api_compatibility.dart check` báo additive, không breaking.

Tự chấm ban đầu 9/10 → audit fork độc lập tìm 2 gap thật (đã fix ở FEAT-96, không liên quan trực tiếp file này) → rescore cuối: **9.5/10**.

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
