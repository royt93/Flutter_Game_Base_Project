---
id: BUG-50
title: "DeepLinkCommandRouter.dispatch: query params ghi đè path params, trái với doc comment của chính class"
type: bug
priority: P1
effort: XS
source: "agy (độc lập), verify lại qua Read lib/core/deep_link_command_router.dart:70-80"
---

## Vị trí
`lib/core/deep_link_command_router.dart` — `dispatch()`, dòng ~77.

## Hiện trạng
Doc comment cam kết: "a query key never overrides path param of the same name, since path params are captured first". Nhưng code thực thi `params.addAll(uri.queryParameters);` sau khi đã set path params — `Map.addAll` ghi đè key trùng, trực tiếp vi phạm cam kết.

## Vì sao cần / Hậu quả
Deep link dạng `myapp://level/42?level=999` (path param `level=42`, query param `level=999` — vô tình hoặc cố ý) sẽ bị query đè lên path, sai với hành vi đã tài liệu hoá và có thể bị lợi dụng (URL chia sẻ công khai có thể chèn query param để ép app vào 1 state khác ý định ban đầu của path).

## Đề xuất
Đổi `params.addAll(uri.queryParameters)` thành `uri.queryParameters.forEach((k, v) => params.putIfAbsent(k, () => v));` — query chỉ điền vào key CHƯA có, không đè key path đã capture.

## Acceptance criteria
- [ ] URI có path param và query param cùng tên — path param được giữ nguyên, query không đè lên.
- [ ] Query param không trùng tên path param nào vẫn được thêm vào `params` như cũ.
- [ ] Test hiện có của `deep_link_command_router_test.dart` vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-50-deep-link-query-overrides-path-params.md` này trước khi làm. Đọc toàn bộ `lib/core/deep_link_command_router.dart` và test hiện có trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (fix 1 dòng, unit test đủ chứng minh).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Rất cao — tự Read trực tiếp code, `params.addAll(uri.queryParameters)` xác nhận đúng, mâu thuẫn trực tiếp với doc comment cùng file. Không trùng task nào trong `doc/task/done/`.
