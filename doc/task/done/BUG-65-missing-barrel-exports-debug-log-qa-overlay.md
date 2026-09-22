---
id: BUG-65
title: "lib/roy_casual_kit.dart không export debug_log.dart và debug_qa_overlay.dart — 2 API công khai không dùng được từ ngoài package"
type: bug
priority: P1
effort: S
source: "agy (độc lập), verify lại qua grep lib/roy_casual_kit.dart — xác nhận không có export nào cho 2 file này"
---

## Vị trí
`lib/roy_casual_kit.dart` (file barrel export chính của package).

## Hiện trạng
Đã grep xác nhận `lib/roy_casual_kit.dart` không chứa bất kỳ `export` nào cho `core/debug_log.dart` (hàm `dlog()`) hoặc `presentation/widgets/debug_qa_overlay.dart` (`DebugQaOverlay`). CLAUDE.md mô tả cả 2 như API công khai quan trọng (`dlog()` được khuyến nghị dùng thay `print`, `DebugQaOverlay` được khuyến nghị bọc app root) — nhưng 1 consumer app import `package:roy_casual_kit/roy_casual_kit.dart` (cách import chuẩn theo README) sẽ KHÔNG thấy 2 API này, phải tự `import 'package:roy_casual_kit/core/debug_log.dart';` trực tiếp (đường dẫn nội bộ, không phải API surface công khai chính thức).

## Vì sao cần / Hậu quả
Đây chính là loại vấn đề mà tích hợp viên ban đầu phàn nàn (README/guide không đầy đủ) — 2 tính năng được document rõ trong CLAUDE.md/README nhưng không thể dùng qua import chuẩn, buộc consumer phải tự dò đường dẫn nội bộ (dễ vỡ nếu cấu trúc file nội bộ đổi trong tương lai, vi phạm nguyên tắc chỉ barrel export là API ổn định).

## Đề xuất
Thêm 2 dòng export vào `lib/roy_casual_kit.dart`:
```dart
export 'core/debug_log.dart';
export 'presentation/widgets/debug_qa_overlay.dart';
```
Chạy `dart run tool/api_compatibility.dart snapshot` để cập nhật `tool/api_snapshot.json` (bắt buộc theo CLAUDE.md khi đổi export).

## Acceptance criteria
- [x] `lib/roy_casual_kit.dart` export cả `dlog`/`debug_log.dart` và `DebugQaOverlay`/`debug_qa_overlay.dart`.
- [x] `tool/api_snapshot.json` được cập nhật đúng qua `dart run tool/api_compatibility.dart snapshot`, `dart run tool/api_compatibility.dart check` pass.
- [x] Test: 1 file test import `package:roy_casual_kit/roy_casual_kit.dart` (barrel duy nhất) rồi gọi `dlog(...)` và dựng `DebugQaOverlay` — biên dịch/chạy thành công không cần import path nội bộ nào khác.
- [x] Không export thêm bất kỳ symbol nào khác ngoài 2 file này (tránh mở rộng API surface ngoài ý muốn).

## Quyết định
Fix đúng 2 dòng như đề xuất, đặt đúng vị trí alphabet gần nhất trong từng nhóm export hiện có (`core/debug_log.dart` giữa `daily_quest_service.dart`/`deep_link_command_router.dart`; `presentation/widgets/debug_qa_overlay.dart` giữa `aurora_bg_layer.dart`/`flame_tracked_overlay.dart`). `dart run tool/api_compatibility.dart check` trước khi regenerate báo `additive` (exit code 0, KHÔNG fail CI vì chỉ thêm, không xoá/đổi tên) — vẫn chạy `snapshot` để cập nhật baseline đúng theo hướng dẫn CLAUDE.md, tránh baseline cũ dần lệch thực tế.

Phát hiện thêm khi chạy `flutter analyze` sau khi thêm export: `example/lib/main.dart` và `example/integration_test/app_boot_test.dart` đã tự import trực tiếp `core/debug_log.dart`/`presentation/widgets/debug_qa_overlay.dart` (đường dẫn nội bộ) SONG SONG với barrel — giờ dư thừa (`unnecessary_import`), dọn sạch luôn (xoá 2 import nội bộ, chỉ giữ barrel) — đúng tinh thần bug: consumer giờ chỉ cần barrel.

**TDD verify**: test mới `test/roy_casual_kit_exports_test.dart` CHỈ import barrel (`package:roy_casual_kit/roy_casual_kit.dart`), không import bất kỳ path nội bộ nào — gọi `dlog(...)` thật + dựng `DebugQaOverlay` thật trong widget tree. `git stash` riêng `lib/roy_casual_kit.dart`, chạy test — FAIL Ở MỨC BIÊN DỊCH đúng trên code cũ (`Method not found: 'dlog'`, `Method not found: 'DebugQaOverlay'`) — đây là hình thức "fail without fix" mạnh nhất có thể cho 1 bug export-missing (không compile được, không phải lỗi assertion runtime). `git stash pop`, chạy lại — 2/2 pass.

Kết quả cuối: `flutter analyze` root sạch (gồm cả dọn `unnecessary_import` ở `example/`), `flutter test --exclude-tags slow` root 2090 pass / -19 fail (baseline golden có sẵn, không liên quan), `dart run tool/api_compatibility.dart check` → `unchanged` (đã regenerate snapshot), `dart pub publish --dry-run` chỉ còn cảnh báo tiêu chuẩn (uncommitted files, version chưa bump), `example/` `flutter analyze` sạch + `flutter test --exclude-tags slow` 132/132 pass.

Tự chấm: **9.5/10** — root cause đúng, fix tối thiểu đúng scope (không export thừa symbol nào khác), TDD dùng compile-failure làm bằng chứng mạnh nhất có thể cho loại bug này, dọn dẹp thêm 2 import thừa phát sinh trực tiếp từ chính thay đổi, không phá test cũ.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-65-missing-barrel-exports-debug-log-qa-overlay.md` này trước khi làm. Đọc toàn bộ `lib/roy_casual_kit.dart` (danh sách export hiện có, để thêm đúng vị trí/nhóm phù hợp) và `tool/api_compatibility.dart` (cơ chế snapshot/check) trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`, cùng `dart run tool/api_compatibility.dart check` pass.
4. Không cần smoke test device bắt buộc (chỉ thêm export, không đổi hành vi runtime).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Rất cao — tự grep trực tiếp `lib/roy_casual_kit.dart`, xác nhận không có export nào cho 2 file này. Fix cơ học, rủi ro thấp, giá trị cao (đúng vấn đề gốc mà tích hợp viên đã phàn nàn ở đầu phiên làm việc này). Không trùng task nào trong `doc/task/done/`.
