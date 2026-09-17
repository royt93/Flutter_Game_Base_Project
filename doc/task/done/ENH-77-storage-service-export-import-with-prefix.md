---
id: ENH-77
title: "StorageService thiếu exportWithPrefix/importWithPrefix — không backup/restore riêng 1 save-slot được"
type: enhancement
priority: medium
effort: S
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/core/storage_service.dart`)
---

## Vị trí
Mở rộng — `lib/core/storage_service.dart` (`StorageService`).

## Hiện trạng
`StorageService` có `exportAll()` (dòng 277, toàn bộ storage) và `removeAllWithPrefix(prefix)` (dòng 344, IDEA-56 — xoá đúng các key thuộc 1 prefix, dùng lại `importAll` để có rollback-on-error). Nhưng KHÔNG có cặp đối xứng `exportWithPrefix`/`importWithPrefix` — không cách nào backup/restore/cloud-sync CHỈ dữ liệu của 1 `SaveSlotManager` slot (namespace qua `keyFor(slotId, suffix)`, đã có từ IDEA-56, và giờ 8 service persist đã nối được qua ENH-69/71/73) một cách độc lập. Muốn backup 1 slot, caller phải tự gọi `exportAll()` rồi tự lọc map theo đúng quy ước `keyFor` bằng tay — dễ sai (quên đúng prefix, lẫn key của slot khác).

## Vì sao cần / Hậu quả
`SaveSlotManager`/`keyFor` (IDEA-56) + 8 service (`LocalScoreboardService` ENH-69, 6 service ENH-71, `EconomyWallet` ENH-73) đã xây xong toàn bộ hạ tầng "1 slot = 1 tập key riêng namespace". `BackupRestorePanel` (ENH-67) hiện tại chỉ export/import TOÀN BỘ storage — không thể backup/restore/cloud-sync RIÊNG 1 slot, dù đây chính là use case tự nhiên nhất của multi-save-slot game (ví dụ: người chơi muốn chia sẻ save của 1 nhân vật, hoặc app đồng bộ cloud từng slot độc lập để tránh 1 slot lỗi kéo hỏng slot khác).

## Đề xuất
Thêm 2 method mới, dùng lại đúng cơ chế atomicity/rollback-on-error của `importAll` (giống cách `removeAllWithPrefix` đã làm) — không phát minh cơ chế persist mới:

```dart
/// Every key currently in storage that starts with [prefix] — e.g.
/// backing up/cloud-syncing just one save slot's namespaced keys
/// (IDEA-56) without capturing any other slot's. [prefix] must not be
/// empty — same reasoning as [removeAllWithPrefix]: an empty prefix
/// would just be [exportAll] under a name that doesn't say so.
Map<String, Object> exportWithPrefix(String prefix) {
  if (prefix.isEmpty) {
    throw ArgumentError.value(prefix, 'prefix', 'must not be empty');
  }
  return {
    for (final entry in exportAll().entries)
      if (entry.key.startsWith(prefix)) entry.key: entry.value,
  };
}

/// Restores [data] as the complete set of keys under [prefix], leaving
/// every OTHER key untouched — the write-side counterpart of
/// [exportWithPrefix]. A key already under [prefix] but missing from
/// [data] is removed (mirrors [importAll] REPLACING a profile, scoped
/// to just this prefix). Every key in [data] must start with [prefix]
/// — guards against a caller accidentally restoring another slot's
/// backup into this one. Built on [importAll], so the same
/// rollback-on-error guarantee applies.
Future<void> importWithPrefix(String prefix, Map<String, Object?> data) {
  if (prefix.isEmpty) {
    throw ArgumentError.value(prefix, 'prefix', 'must not be empty');
  }
  if (data.keys.any((key) => !key.startsWith(prefix))) {
    throw ArgumentError.value(data, 'data', 'every key must start with $prefix');
  }
  final merged = <String, Object?>{
    for (final entry in exportAll().entries)
      if (!entry.key.startsWith(prefix)) entry.key: entry.value,
    ...data,
  };
  return importAll(merged);
}
```

## Acceptance criteria
- [x] `exportWithPrefix('')`: throw `ArgumentError`.
- [x] `exportWithPrefix(prefix)`: trả đúng CHỈ các key bắt đầu bằng `prefix`, không lẫn key khác.
- [x] `importWithPrefix('', data)`: throw `ArgumentError`.
- [x] `importWithPrefix(prefix, data)` với `data` có key KHÔNG bắt đầu bằng `prefix`: throw `ArgumentError`, không ghi gì.
- [x] `importWithPrefix(prefix, data)` hợp lệ: key ngoài `prefix` giữ nguyên, key trong `prefix` được thay thế đúng bằng `data` (kể cả xoá key cũ trong `prefix` không có trong `data` mới).
- [x] `exportWithPrefix` rồi `importWithPrefix` cùng prefix lên 1 storage khác (hoặc storage đã bị đổi giữa chừng) khôi phục đúng y hệt dữ liệu đã export.
- [x] Lỗi giữa chừng khi `importWithPrefix` (mock `_replaceAll` throw, hoặc tương tự cách test `importAll` rollback hiện có) rollback đúng, không để storage half-restored.
- [x] Không đổi hành vi `exportAll`/`importAll`/`eraseAll`/`removeAllWithPrefix` hiện có; không phá test cũ trong `test/core/storage_service_test.dart`.
- [x] Test: unit test đầy đủ mọi case trên.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không bắt buộc đụng `example/` (nếu muốn minh hoạ, cân nhắc `BackupRestorePanel` nhận optional `storagePrefix` để backup/restore riêng 1 slot — không bắt buộc, effort tăng đáng kể nếu làm, nên tách task riêng nếu muốn).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-77-storage-service-export-import-with-prefix.md` này trước khi làm. Đọc toàn bộ `lib/core/storage_service.dart` (đặc biệt `exportAll`/`importAll`/`removeAllWithPrefix`/`_replaceAll`) và `test/core/storage_service_test.dart` (tìm cách test hiện có đã mock lỗi giữa chừng cho `importAll` rollback, dùng lại đúng kỹ thuật đó cho `importWithPrefix`) trước khi thêm method mới. Implement bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng nhất quán với `removeAllWithPrefix`/IDEA-56, dùng lại `importAll` thay vì tự viết cơ chế persist mới, không phá API/test hiện có, không over-engineer).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria — đặc biệt case rollback-on-error.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không bắt buộc đụng `example/`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `storage_service.dart`: `exportAll`/`importAll`/`removeAllWithPrefix` tồn tại đúng vị trí mô tả, không có `exportWithPrefix`/`importWithPrefix` nào. `removeAllWithPrefix` đã chứng minh pattern "tái sử dụng `importAll` cho atomicity thay vì tự viết logic mới" hoạt động tốt (IDEA-56 đã qua device smoke test). Effort vừa (S — 2 method, cần test rollback-on-error kỹ hơn `removeAllWithPrefix` 1 chút vì có thêm validate `data`'s keys), không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có trong `doc/task/done/`.

## Quyết định

Đúng như đề xuất — 2 method mới, cả 2 đều dùng lại `exportAll`/`importAll` sẵn có cho việc lọc/gộp/persist, không tự viết cơ chế atomicity mới. `importWithPrefix` validate `data`'s keys đều thuộc `prefix` TRƯỚC khi động tới storage — throw đồng bộ (không phải reject Future), giữ nguyên storage nếu validate fail.

**Test:** 7 test mới trong `test/core/storage_service_test.dart` nhóm "ENH-77" — export đúng lọc, export prefix rỗng, import prefix rỗng, import data sai prefix, import hợp lệ (thay đúng + xoá key cũ trong prefix không còn trong data mới + giữ nguyên key ngoài prefix), round-trip export→removeAllWithPrefix→import khôi phục đúng, và rollback khi gặp lỗi giữa chừng (dùng đúng kỹ thuật đã có trong file — feed 1 value kiểu không hỗ trợ để trigger `FormatException` từ `importAll`'s type-check nội bộ, không cần mock `_replaceAll`).

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1259/1259 pass. Không đụng `example/`/`BackupRestorePanel` (không bắt buộc, để dành cho task riêng nếu cần).

**Tự chấm điểm: 9.5/10** — dùng đúng cơ chế atomicity có sẵn (không phát minh mới), test bao phủ cả rollback-on-error, đối xứng đúng với `removeAllWithPrefix`. Trừ 0.5 vì đây là API mới hoàn toàn (không phải mở rộng 1 hàm có sẵn) nên bề mặt API tăng thêm 2 method công khai — cân nhắc hợp lý nhưng vẫn là surface area lớn hơn các ENH khác trong đợt này.
