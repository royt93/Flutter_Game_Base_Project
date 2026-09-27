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

- [ ] Unit test provider download-throw → `syncWith` trả failure (kind network), không throw.
- [ ] Upload-throw (nhánh local-newer) cũng trả failure thay vì throw.

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

Cao. Đã verify dòng 219 `await provider.download()` ngoài try, các nhánh sau (upload, conflict) có xử lý lỗi riêng.
