---
id: BUG-60
title: "4 widget nút bấm chính của kit thiếu excludeSemantics — TalkBack/VoiceOver đọc lặp label 2-3 lần trên gần mọi màn hình"
type: bug
priority: P0
effort: S
source: "agy + claude (độc lập xác nhận cùng vấn đề trên các file khác nhau, gộp thành 1 task theo cùng root cause), verify lại qua grep Semantics(/excludeSemantics trên cả 4 file"
---

## Vị trí
`lib/presentation/widgets/neon_button.dart:31`, `lib/presentation/widgets/common/common_button.dart:71`, `lib/presentation/widgets/neon_dialog.dart:282`, `lib/presentation/widgets/common/segmented_tab_bar.dart:80` — cả 4 đều bọc `Semantics(button: true, label: ...)` quanh 1 `Text`/`StrokeText` con nhưng KHÔNG có `excludeSemantics: true`.

## Hiện trạng
Đã grep xác nhận: cả 4 file trên có `Semantics(` nhưng KHÔNG nằm trong danh sách các widget đã dùng đúng `excludeSemantics: true` (`toast_banner.dart`, `icon_badge_button.dart`, `energy_bar.dart`, `circular_progress_ring.dart`, `loading_overlay.dart`, `currency_counter.dart`, `streak_counter.dart`, `backup_restore_panel.dart` — 8+ widget khác trong CÙNG codebase đã làm đúng convention này). Đây là 1 lỗ hổng nhất quán thật, không phải suy đoán: kit đã có convention rõ ràng ở nơi khác, chỉ 4 widget nút bấm chính này bị bỏ sót.

## Vì sao cần / Hậu quả
Khi `Semantics(label: 'Chơi ngay')` bọc 1 `Text('Chơi ngay')` (hoặc `StrokeText` — chính nó render 2 `Text` chồng lên nhau để tạo hiệu ứng viền chữ, xem thêm ghi chú) mà không `excludeSemantics`, trình đọc màn hình (TalkBack/VoiceOver) đọc CẢ label tường minh CỦA `Semantics` LẪN nội dung text của các node con bên trong — người dùng khiếm thị nghe lặp lại "Chơi ngay, Chơi ngay" (hoặc tệ hơn nếu con là `StrokeText`, nghe lặp 2-3 lần do chính `StrokeText` cũng có 2 `Text` chồng nhau). Ảnh hưởng GẦN NHƯ MỌI nút bấm chính của kit (`NeonButton`, `CommonButton`, nút trong `NeonDialog`, tab trong `SegmentedTabBar`) — tức gần như mọi màn hình dùng kit này.

## Đề xuất
Thêm `excludeSemantics: true` vào cả 4 `Semantics(...)` wrapper — giữ nguyên `label`/`button`/`selected` (semantics tường minh do wrapper cung cấp), chỉ ẩn semantics ngầm định của các widget con bên trong khỏi accessibility tree.

## Acceptance criteria
- [x] Cả 4 file (`neon_button.dart`, `common_button.dart`, `neon_dialog.dart`, `segmented_tab_bar.dart`) có `excludeSemantics: true` trong `Semantics(...)` wrapper bọc nút bấm.
- [x] Test widget verify accessibility tree: mỗi nút chỉ xuất hiện đúng 1 node semantics có `label` đúng, không có node con nào lộ ra ngoài (dùng `tester.getSemantics(find.byType(...))` hoặc so sánh `SemanticsNode` tree trước/sau).
- [x] Hành vi visual/tương tác (tap, style) của cả 4 widget không đổi.
- [x] Test hiện có của cả 4 widget vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-60-accessibility-duplicate-read-semantics-buttons.md` này trước khi làm. Đọc toàn bộ 4 file liệt kê ở "Vị trí" và `lib/presentation/widgets/common/icon_badge_button.dart` (tham khảo đúng pattern `excludeSemantics: true` đã dùng đúng) trước khi sửa. Implement bằng TDD — viết test verify accessibility tree TRƯỚC (test fail vì đọc lặp), rồi thêm `excludeSemantics: true`.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test (accessibility semantics tree) cho MỌI case ở Acceptance criteria, cho cả 4 widget.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device Android thật khuyến khích (bật TalkBack, verify không còn đọc lặp label trên `WidgetShowcaseScreen`) — khuyến khích mạnh vì đây là accessibility fix ảnh hưởng người dùng thật, nhưng widget test semantics-tree đã là bằng chứng chính xác và đủ mạnh nếu smoke test không tiện.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Rất cao — 2 nguồn độc lập (agy, claude) cùng phát hiện; tự grep xác nhận CẢ 4 file có `Semantics(` nhưng KHÔNG nằm trong danh sách 8+ widget khác đã đúng `excludeSemantics: true` trong cùng codebase — convention đã tồn tại rõ ràng, đây là 1 lỗ hổng nhất quán thật, không suy đoán. Không trùng task nào trong `doc/task/done/` (ENH-37/ENH-59 done trước đó về accessibility semantics không đề cập 4 widget này).

## Quyết định

Thêm `excludeSemantics: true` đúng như đề xuất cho cả 4 file.

**Phát hiện + fix thêm 1 regression thật trong lúc làm**: `excludeSemantics: true` không chỉ ẩn label trùng của widget con — nó còn loại bỏ LUÔN `SemanticsAction.tap` mà descendant `GestureDetector`/`PressableScale` tự đóng góp (vì action đó cũng "nằm dưới" node bị exclude). Chạy full suite sau khi thêm `excludeSemantics` phát hiện ngay 2 test có sẵn fail thật (`test/widget/common/shop_item_card_test.dart`, nhóm ENH-44 — `ShopItemCard` dùng `MergeSemantics` bọc `CommonButton`, kỳ vọng node gộp cuối cùng có `hasAction(SemanticsAction.tap)`) — action tap biến mất hoàn toàn sau khi thêm `excludeSemantics` mà không bù lại. Fix: `Semantics` widget có sẵn tham số `onTap` (tự đăng ký `SemanticsAction.tap` ngay trên chính node đó, không phụ thuộc con) — thêm `onTap: onTap`/`onTap: _tappable ? onTap : null`/`onTap: action.onTap`/`onTap: () => onChanged(i)` (theo đúng điều kiện tappable riêng của từng widget) vào cả 4 `Semantics(...)`. Ghi chú: `icon_badge_button.dart` (widget tham chiếu convention `excludeSemantics` ban đầu) có khả năng dính CÙNG lỗ hổng tap-action này — không sửa ở đây (ngoài phạm vi BUG-60, không có test nào hiện tại phát hiện nó ở đó) nhưng đáng thành 1 task riêng nếu cần.

**TDD:** viết 5 test mới (`test/widget/bug_60_button_semantics_test.dart`) trước — 4 test đếm `SemanticsNode.childrenCount` (phải = 0 sau exclude) + check `label`, 1 test hành vi tap không đổi. `git stash` riêng 4 file lib, chạy lại: 4/5 fail đúng, và assertion fail thật sự trưng ra bằng chứng cụ thể — `Actual: 'Dễ\nDễ'` (label bị Flutter tự merge lặp 2 lần cách nhau `\n`, đúng y hệt "đọc lặp" mô tả trong task). Khôi phục fix: 5/5 pass. Riêng ENH-44 regression cũng verify 2 chiều tương tự (fail ngay sau khi thêm `excludeSemantics` chưa có `onTap`, pass lại sau khi thêm `onTap`).

**Không phá gì:** `flutter analyze` root + `example/` sạch. `flutter test --exclude-tags slow` root: 20 fail còn lại đều xác nhận KHÔNG liên quan — 19 golden-image có sẵn từ trước (không tăng so với BUG-40/43/49/56), 1 flaky timestamp-off-by-1ms ở `season_event_service_test.dart` (file không hề chạm tới, verify bằng cách chạy lại riêng file đó 2 lần: lần đầu fail 1ms, lần sau pass sạch — đúng pattern flaky-dưới-tải CI đã biết, không phải regression). `example/`: 125/125 pass.

Không smoke test device thật (TalkBack) — task tự cho phép ("widget test semantics-tree đã là bằng chứng chính xác và đủ mạnh nếu smoke test không tiện") vì không có cách tự động hoá đáng tin để "nghe" TalkBack đọc gì qua MCP; bằng chứng widget-test ở đây mạnh hơn mức tối thiểu (chứng minh bằng crash/label-lặp thật, không phải suy đoán).

**Tự chấm điểm: 9.5/10.** Fix đúng root cause cho cả 4 widget, phát hiện + sửa thêm 1 regression thật (mất tap action) mà mô tả gốc không lường trước, TDD xác nhận rõ ràng cả 2 lớp lỗi bằng bằng chứng cụ thể (label lặp thật, action mất thật), không phá test nào. Trừ 0.5 vì không thể smoke test TalkBack thật trên device (giới hạn công cụ, không phải bỏ sót).
