---
id: BUG-62
title: "widget_showcase_screen.dart: ConnectivityCoordinator demo giữ tham chiếu cũ khi mở lại màn hình nhiều lần"
type: bug
priority: P1
effort: S
source: "agy (độc lập) — cần verify lại số dòng chính xác trước khi implement"
---

## Vị trí
`example/lib/screens/widget_showcase_screen.dart` — khu vực demo `ConnectivityCoordinator`.

## Hiện trạng
`ConnectivityCoordinator` được đăng ký `permanent: true` với 1 `probe` callback tham chiếu tới instance `_WidgetShowcaseScreenState` hiện tại. Khi màn hình bị đóng rồi mở lại (State instance MỚI được tạo), coordinator (permanent, không bị GetX huỷ) vẫn giữ callback trỏ tới State CŨ đã unmounted.

## Vì sao cần / Hậu quả
Sau khi mở lại màn hình nhiều lần, các probe callback cũ (trỏ instance State đã dispose) có thể vẫn được gọi ngầm bởi coordinator permanent — không crash ngay (do closures Dart không tự động throw khi state đã dispose trừ khi truy cập `setState`), nhưng là leak tham chiếu State cũ, và nếu closure có gọi `setState`, sẽ gây lỗi "setState() called after dispose()" tương tự các bug mounted-guard khác trong cùng file.

## Đề xuất
Không đăng ký `permanent: true` cho coordinator demo giả lập chỉ dùng trong 1 màn hình showcase (dùng `Get.put(..., permanent: false)` hoặc tự quản lý instance cục bộ trong State, dispose đúng trong `dispose()`), hoặc cập nhật lại callback mỗi lần `initState()` chạy để luôn trỏ đúng instance State hiện tại.

## Acceptance criteria
- [x] Mở/đóng `WidgetShowcaseScreen` nhiều lần — probe callback của `ConnectivityCoordinator` demo luôn trỏ đúng instance State hiện tại, không giữ tham chiếu State cũ đã dispose.
- [x] Demo `ConnectivityCoordinator` vẫn hoạt động đúng (hiển thị đúng trạng thái mạng) sau khi sửa.
- [x] Test hiện có của `widget_showcase_screen_test.dart` vẫn pass.

## Quyết định
Tự Read lại đúng khu vực demo trước khi sửa — xác nhận đúng như agy mô tả, VÀ phát hiện thêm: không chỉ `probe` bị stale, `_connectivitySignal` (FakeConnectivitySignal) CŨNG bị stale/mồ côi theo cùng cơ chế — `Get.put()` chỉ chạy khi `.maybe` KHÔNG tìm thấy instance cũ, nên lần mở lại thứ 2 trở đi, `_connectivitySignal` MỚI của State mới không bao giờ thực sự được coordinator (cũ, đã giữ lại signal CŨ từ lần đầu) lắng nghe — nghĩa là nút bật/tắt "Interface up" ở lần mở lại KHÔNG có tác dụng gì cả, một bug hành vi quan sát được thật sự (không chỉ leak tham chiếu lý thuyết).

Chọn phương án 1 trong đề xuất: không tái sử dụng instance cũ qua `.maybe`. `initState()` giờ luôn xoá đăng ký cũ (`Get.delete<ConnectivityCoordinator>(force: true)` nếu có) rồi tạo coordinator MỚI với `probe`/`signal` của CHÍNH State hiện tại. `dispose()` xoá đăng ký + đóng `_connectivitySignal` (StreamController riêng của signal, coordinator không tự đóng hộ vì nó là caller-owned).

**TDD verify**: viết test "mở lại screen" — lần thử ĐẦU TIÊN dùng `_pumpShowcase(tester)` gọi 2 lần liên tiếp trong cùng test KHÔNG tái hiện được bug (`const WidgetShowcaseScreen()` không key, Flutter tái dùng CÙNG State qua `didUpdateWidget` thay vì dispose+tạo mới — `initState()` không chạy lại lần 2, nên fail ở CẢ code cũ lẫn code đã fix, không phân biệt được). Sửa lại: chèn `tester.pumpWidget(const SizedBox())` ở giữa để buộc dispose thật (mô phỏng đúng route pop) trước khi "mở lại" — `git stash` riêng `example/lib/screens/widget_showcase_screen.dart`, chạy lại — FAIL đúng trên code cũ (`State: offline` không tìm thấy — coordinator mở lại vẫn kẹt ở "online" từ lần trước). `git stash pop`, chạy lại toàn group `FEAT-62` — 5/5 pass, bao gồm cả việc bật interface Ở LẦN MỞ LẠI vẫn chuyển đúng sang "online" (chứng minh signal MỚI thật sự được lắng nghe, không phải signal cũ vô tác dụng).

Kết quả cuối: `example/` `flutter analyze` sạch + `flutter test --exclude-tags slow` 130/130 pass. Root `flutter analyze` sạch, `dart run tool/api_compatibility.dart check` unchanged (không đổi `lib/` package, chỉ `example/`). Không smoke test device thật (task ghi không bắt buộc, leak tham chiếu nội bộ khó quan sát qua device).

Tự chấm: **9.5/10** — root cause đúng và MỞ RỘNG phát hiện thêm phần `signal` cũng bị stale (không chỉ `probe` như mô tả gốc), fix dọn dẹp đúng cả 2 lẫn cả StreamController. TDD ban đầu có sai lầm về cách mô phỏng "mở lại" (test đầu không phân biệt được code cũ/mới) nhưng đã tự phát hiện và sửa đúng trước khi coi là xong — không nộp 1 test giả.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-62-widget-showcase-connectivity-stale-signal.md` này trước khi làm. Đọc toàn bộ khu vực demo `ConnectivityCoordinator` trong `example/lib/screens/widget_showcase_screen.dart` — TỰ XÁC NHẬN lại đúng số dòng/cơ chế trước khi sửa (nguồn phát hiện chưa tự verify số dòng chính xác). Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở `example/`.
4. Không cần smoke test device bắt buộc (leak tham chiếu nội bộ, khó quan sát trực tiếp qua device trừ khi dùng DevTools memory profiler).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — dựa trên mô tả agy, CHƯA tự Read lại đúng số dòng/đoạn code trong `widget_showcase_screen.dart` (file rất lớn, hơn 2500 dòng) do khối lượng batch verify lớn của đợt audit này. Người thực hiện BẮT BUỘC tự đọc lại chính xác trước khi sửa (đã ghi rõ trong Prompt) — nếu không xác nhận được vấn đề như mô tả, ghi rõ lý do và có thể đóng task này là "không tái hiện được" thay vì cố sửa 1 vấn đề không tồn tại. Không trùng task nào trong `doc/task/done/`.
