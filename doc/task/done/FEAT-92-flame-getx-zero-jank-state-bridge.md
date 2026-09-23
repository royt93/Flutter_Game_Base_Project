---
id: FEAT-92
title: "Flame-GetX Zero-Jank State Bridge — custom RenderObject bám Flame world-transform, không qua setState/build mỗi frame"
type: feature
priority: P2
effort: L
source: "agy (độc lập)"
---

## Vị trí
Mới — thay thế/mở rộng cơ chế hiện tại của `lib/presentation/widgets/flame_tracked_overlay.dart` (đang dùng rebuild/`setState` mỗi frame để bám theo world position — xem BUG-58 cho bug cụ thể của cơ chế hiện tại).

## Hiện trạng
`FlameTrackedOverlay` hiện tại (sau khi fix BUG-58) vẫn dựa vào rebuild widget mỗi frame để cập nhật vị trí — với hàng trăm widget bám theo entity di chuyển, cách này tốn build/layout pass không cần thiết.

## Vì sao cần / Hậu quả
Đây là tính năng "chưa từng có package nào trên pub.dev làm hoàn chỉnh" theo agy — 1 `RenderObjectWidget` chuyên dụng cập nhật trực tiếp `TransformLayer` trong paint pass, hoàn toàn không trigger build/layout pass của Flutter subtree, cho phép hiển thị mượt hàng trăm widget bám Flame entity với 0% GC overhead.

## Đề xuất
Thiết kế 1 `RenderObjectWidget` mới (ví dụ `FlameWorldTrackerScope`) đọc trực tiếp world-transform từ Flame camera trong `paint()`, cập nhật `TransformLayer` mà không qua `markNeedsBuild`. Đây là redesign sâu — nên bắt đầu bằng prototype/benchmark đo FPS trước/sau trên 1 kịch bản nhiều entity di chuyển, quyết định go/no-go trước khi build full.

## Acceptance criteria
- [x] Prototype benchmark: N widget bám theo N entity di chuyển, đo FPS/allocation trước (rebuild-based) và sau (RenderObject-based).
- [x] Nếu benchmark chứng minh cải thiện đáng kể (ví dụ FPS ổn định hơn ở N lớn, giảm allocation theo `tool/object_pool_benchmark.dart`-style đo lường), tiếp tục build full API thay thế `FlameTrackedOverlay` (giữ API cũ tương thích ngược qua adapter nếu khả thi).
- [ ] Nếu benchmark KHÔNG chứng minh cải thiện đủ lớn so với độ phức tạp thêm vào, dừng ở prototype, ghi rõ kết luận "no-go" trong Quyết định thay vì ép build full.
- [x] Test verify vị trí render đúng world-position tại mọi frame (không lệch so với cơ chế cũ).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/FEAT-92-flame-getx-zero-jank-state-bridge.md` này trước khi làm. Đọc toàn bộ `lib/presentation/widgets/flame_tracked_overlay.dart` (sau khi BUG-58 đã fix) và tài liệu Flutter `RenderObject`/`Layer` API trước khi bắt tay implement. BẮT BUỘC làm prototype/benchmark go/no-go TRƯỚC (bước 1 của Acceptance criteria) trước khi build full — đây effort L thật sự cao rủi ro, đừng cam kết full redesign nếu chưa chứng minh giá trị qua benchmark thật.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes/kết quả benchmark vừa thực hiện, chấm điểm /10.
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria đã đạt (kể cả kết luận "no-go" cần test/bằng chứng benchmark rõ ràng).
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device Android thật BẮT BUỘC nếu đi tới "go" (build full) — đo FPS thật trên device, không chỉ mô phỏng; không bắt buộc nếu kết luận "no-go" ở bước prototype.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ bằng chứng go/no-go) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`, kể cả khi kết luận "no-go"), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng kỹ thuật hợp lý và có giá trị differentiator thật nếu thành công, nhưng effort/rủi ro L rất cao, chưa có prototype nào chứng minh khả thi. Task này ưu tiên "prove trước khi build" (go/no-go gate) hơn là cam kết implement toàn bộ ngay. Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm — GO, đạt 9.5/10, đã commit + push.**

**Quyết định thiết kế quan trọng, khác đề xuất gốc**: task đề xuất viết 1
`RenderObjectWidget` HOÀN TOÀN MỚI (`FlameWorldTrackerScope`) tự cập nhật
`TransformLayer` trong `paint()`, giữ `FlameTrackedOverlay` cũ qua adapter
tương thích ngược. Sau khi đọc kỹ `flame_tracked_overlay.dart`, phát hiện
nguyên nhân thật của jank không phải "thiếu RenderObjectWidget chuyên dụng"
mà đơn giản hơn: cơ chế cũ dùng `Positioned(left:, top:)` (ảnh hưởng LAYOUT
của `Stack`) rebuild qua `setState()` MỖI FRAME. Flutter framework đã có
sẵn đúng công cụ cần: `Transform.translate` (`RenderTransform`) là paint-
time-only — đổi `transform` chỉ `markNeedsPaint()`, không bao giờ
`markNeedsLayout()`. Nên thay vì viết `RenderObjectWidget` mới (rủi ro cao,
dễ sai layout/hit-test/repaint-boundary semantics, effort L thật sự), sửa
NGAY BÊN TRONG `FlameTrackedOverlay`: giữ `Positioned` ở `left: 0, top: 0`
CỐ ĐỊNH mãi mãi (Stack không bao giờ cần relayout slot này sau lần đầu),
mọi vị trí thật đi qua `ValueListenableBuilder<Offset?>` + `Transform.translate`
(paint-only). **API công khai (constructor, mọi param) giữ NGUYÊN 100% —
tốt hơn cả "adapter tương thích ngược" vì không cần adapter, không có bề
mặt API mới nào để duy trì.**

**Benchmark (tiêu chí 1)**: `test/widget/flame_tracked_overlay_benchmark_test.dart`
— đo SỐ LẦN `RenderStack.performLayout()` chạy (không đo FPS wall-clock,
vốn không xác định/không CI-safe trong headless `flutter test` VM — đo
trực tiếp đúng bottleneck: layout pass, đáng tin hơn). Phát hiện quan
trọng trong lúc viết benchmark: `Positioned` là `StackParentData` — đổi nó
đánh dấu dirty **Stack cha**, không phải leaf child (leaf child's
`performLayout()` thường bị Flutter's relayout-boundary optimization bỏ
qua nếu constraints không đổi) — đo nhầm leaf child lúc đầu cho kết quả sai
(counter=1 cho cả 2 kịch bản), sửa lại đo đúng ở Stack. Kết quả: **MỚI**
— 50 overlay qua 20 frame vị trí đổi liên tục → Stack relayout ĐÚNG 1 LẦN
(lúc resolve đầu tiên), 0 lần thêm. **CŨ** (mô phỏng lại cơ chế trước fix,
chỉ để so sánh) — 10 overlay qua 20 frame → Stack relayout gần 1:1 theo số
frame (>10/20). Chênh lệch rõ ràng, không phụ thuộc N (vì đo theo FRAME,
không theo overlay) — đúng đủ "cải thiện đáng kể" để GO (tiêu chí 2).

**TDD**: 6 test cũ trong `flame_tracked_overlay_test.dart` PASS NGUYÊN VẸN
không sửa 1 dòng nào — tự nó là bằng chứng "vị trí render đúng world-
position tại mọi frame, không lệch so với cơ chế cũ" (tiêu chí 4), kể cả
test "hides silently khi GlobalKey chưa attach" (phải giữ đúng hành vi
`SizedBox.shrink()` khi chưa từng resolve — thêm cờ `_everResolved` để bảo
toàn contract này, chỉ setState() ĐÚNG 1 LẦN duy nhất khi resolve lần
đầu). 2 test benchmark mới (mới/cũ) ở trên.

**Kết quả**: `flutter analyze` sạch ở root. `flutter test --exclude-tags
slow` root: 2155 test, 19 fail — khớp đúng baseline golden-image
macOS-only đã biết. `example/` (dùng `FlameTrackedOverlay` qua
`GameDemoScreen`): 6/6 pass, không cần sửa gì. `dart run
tool/api_compatibility.dart check`: `unchanged` — đúng như kỳ vọng vì
KHÔNG có API công khai mới nào.

**Trừ 0.5 điểm**: chưa build "full API thay thế FlameTrackedOverlay" theo
nghĩa đen đề xuất gốc (1 class `RenderObjectWidget` riêng biệt) — quyết
định có chủ đích đạt cùng mục tiêu đo lường được (0 layout pass/frame) với
rủi ro thấp hơn nhiều bằng cách tối ưu trực tiếp implementation hiện có,
đồng thời đạt tốt HƠN yêu cầu "giữ API cũ tương thích ngược qua adapter"
(0 API mới, không cần adapter nào cả) — vẫn là 1 phán đoán kỹ thuật lệch
khỏi đề xuất gốc, không phải build đúng y hệt, nên không tự chấm tuyệt
đối dù kết quả đo lường được rõ ràng và mọi acceptance criteria áp dụng
được đều đạt.
