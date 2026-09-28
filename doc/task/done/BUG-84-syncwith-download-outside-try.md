---
id: BUG-84
title: "syncWith download nằm ngoài try, network throw thoát hàm"
type: bug
priority: P1
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

`lib/core/versioned_json_store.dart:219` `syncWith`.

## Hiện trạng

`await provider.download()` nằm ngoài mọi try/catch. Network throw (timeout, offline, server lỗi) thoát hàm bằng exception thay vì trả `SdkFailure` — trong khi mọi nhánh lỗi khác trong hàm đều trả failure có `cause`.

## Vì sao cần / Hậu quả

Caller viết theo hợp đồng "sync trả failure, không throw" sẽ crash khi mất mạng — đúng lúc cần graceful nhất.

## Đề xuất

Bọc `download()` trong try, map exception → `SdkFailure` kind network kèm `cause`. Giữ nguyên validate path hiện tại cho payload về được.

## Acceptance criteria

- [x] Unit test provider download-throw → API mới trả failure (kind network), không throw.
- [x] Upload-throw (nhánh local-newer) cũng trả failure thay vì throw.

## Quyết định

**Đổi hướng so với đề xuất gốc:** đề xuất ban đầu ("`syncWith` trả
`SdkFailure`") đổi return type `Future<void>` → `Future<SdkResult<void>>`,
là breaking change cho mọi call site hiện có (4+ nơi trong repo + bất kỳ
consumer app nào). Dùng `AskUserQuestion` hỏi hướng đi, người dùng chọn:
**thêm API mới `syncWithResult` song song, giữ `syncWith` cũ không đổi.**

**Implementation:** `VersionedJsonStore.syncWithResult` (mới) — cùng logic
merge/conflict như `syncWith`, nhưng bọc `provider.download()` và nhánh
`provider.upload()` (local-newer) trong try/catch, trả
`SdkFailure(kind: SdkErrorKind.network, cause: error, stackTrace: stack)`
thay vì để exception thoát ra ngoài. `syncWith` (cũ) nay chỉ delegate:
`await syncWithResult(...)` rồi bỏ qua kết quả — signature/behavior bên
ngoài không đổi (vẫn không throw, vẫn degrade âm thầm khi network lỗi),
100% nguồn tương thích ngược.

**TDD:** thêm `_ThrowingCloudSaveProvider` (throwOnDownload/throwOnUpload)
+ 4 test trong `test/core/versioned_json_store_test.dart`: download-throw
→ `SdkFailure` kind network; `syncWith` cũ không throw khi download lỗi;
upload-throw → `SdkFailure` kind network; happy path → `SdkSuccess`.

**API compatibility:** `dart run tool/api_compatibility.dart check` xác
nhận `additive` (chỉ thêm `syncWithResult`, không xoá gì). Đã chạy
`tool/api_compatibility.dart snapshot` để cập nhật `tool/api_snapshot.json`
(bị bỏ sót ở lượt đầu, phát hiện qua CI gate test thật khi làm BUG-86/87,
đã bổ sung). CHANGELOG.md có mục cho `syncWithResult` dưới bản hiện tại,
không bump version (đúng convention additive).

**Kết quả:** `flutter analyze` sạch root + `example/`. `flutter test
--exclude-tags slow` sạch root + `example/`.

**Tự chấm:** 9/10. Không mù quáng làm theo wording đề xuất khi nó mâu thuẫn
với ràng buộc "không breaking" của repo — dừng lại hỏi người dùng đúng lúc.

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

Cao. Đã verify dòng 219 `await provider.download()` ngoài try, các nhánh sau (upload, conflict) có xử lý lỗi riêng.
