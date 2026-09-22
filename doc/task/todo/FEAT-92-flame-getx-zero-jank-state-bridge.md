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
- [ ] Prototype benchmark: N widget bám theo N entity di chuyển, đo FPS/allocation trước (rebuild-based) và sau (RenderObject-based).
- [ ] Nếu benchmark chứng minh cải thiện đáng kể (ví dụ FPS ổn định hơn ở N lớn, giảm allocation theo `tool/object_pool_benchmark.dart`-style đo lường), tiếp tục build full API thay thế `FlameTrackedOverlay` (giữ API cũ tương thích ngược qua adapter nếu khả thi).
- [ ] Nếu benchmark KHÔNG chứng minh cải thiện đủ lớn so với độ phức tạp thêm vào, dừng ở prototype, ghi rõ kết luận "no-go" trong Quyết định thay vì ép build full.
- [ ] Test verify vị trí render đúng world-position tại mọi frame (không lệch so với cơ chế cũ).

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
