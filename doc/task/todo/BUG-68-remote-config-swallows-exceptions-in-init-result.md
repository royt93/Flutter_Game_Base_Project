---
id: BUG-68
title: "RemoteConfigService.initResult() luôn trả SdkSuccess kể cả khi fetch remote thất bại — nuốt hết exception"
type: bug
priority: P2
effort: XS
source: "agy (độc lập), khớp với ghi nhận enhancement rộng hơn của codex (2.2) về schema/typed validation — verify lại qua Read lib/core/remote_config_service.dart"
---

## Vị trí
`lib/core/remote_config_service.dart` — `init()`/`initResult()` (~dòng 72-117).

## Hiện trạng
`init()` bắt mọi exception trong lúc fetch remote, gán `_source = RemoteConfigSource.remoteFailed`, rồi tiếp tục — không throw, không trả lỗi ra ngoài. `initResult()` (wrapper trả `SdkResult`) do đó KHÔNG BAO GIỜ bắt được exception nào, luôn trả `SdkSuccess(null)` kể cả khi remote config fetch thất bại hoàn toàn (mất mạng, server lỗi).

## Vì sao cần / Hậu quả
Consumer app gọi `initResult()` để biết boot có thành công hay không sẽ luôn thấy `SdkSuccess` dù thực chất remote config đã fail-over về giá trị local/default — không có cách nào phân biệt "remote fetch thành công" với "remote fetch fail, đang dùng fallback" chỉ qua `SdkResult` trả về, phải tự check thêm `source` field riêng (không nhất quán với ý nghĩa thường có của `SdkResult`).

## Đề xuất
`initResult()` kiểm tra `_source == RemoteConfigSource.remoteFailed` sau khi `init()` chạy xong, trả `SdkFailure(kind: SdkErrorKind.network, ...)` trong trường hợp đó thay vì luôn `SdkSuccess`.

## Acceptance criteria
- [ ] `initResult()` trả `SdkFailure` khi remote fetch thất bại (`source == remoteFailed`).
- [ ] `initResult()` vẫn trả `SdkSuccess` khi remote fetch thành công hoặc dùng đúng asset/local fallback theo thiết kế (không phải lỗi).
- [ ] `init()` (không phải `initResult()`) hành vi không đổi — vẫn never-throws, vẫn set `_source` đúng.
- [ ] Test hiện có của `remote_config_service_test.dart` vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-68-remote-config-swallows-exceptions-in-init-result.md` này trước khi làm. Đọc toàn bộ `lib/core/remote_config_service.dart` (đặc biệt các giá trị `RemoteConfigSource` — phân biệt rõ trường hợp nào là "fail" thật, trường hợp nào là "fallback hợp lệ theo thiết kế") và test hiện có trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (logic thuần).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — 2 nguồn nhắc tới cùng vùng vấn đề (agy: bug cụ thể; codex: enhancement rộng hơn về schema — xem ENH riêng). Chưa tự Read lại chính xác dòng, nhưng logic mô tả (never-throws `init()` khiến `initResult()` không bao giờ thấy exception) là hệ quả logic hợp lý, dễ kiểm chứng khi implement. Không trùng task nào trong `doc/task/done/`.
