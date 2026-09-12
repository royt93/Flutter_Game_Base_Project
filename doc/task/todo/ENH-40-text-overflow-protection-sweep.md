---
id: ENH-40
title: "Bổ sung overflow/FittedBox cho text có thể tràn ở font scale lớn hoặc màn hình hẹp"
type: enhancement
priority: P3
effort: S
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`segmented_tab_bar.dart` (`Text(labels[i])` không có `maxLines`/`overflow`/`FittedBox`), `streak_counter.dart` (`Text('${widget.days}')` không giới hạn, khác với `CurrencyCounter` đã bọc `Flexible(child: FittedBox(...))`), `list_tile_row.dart` (`title`/`subtitle` không có `overflow: TextOverflow.ellipsis`).

## Hiện trạng
Ở font scale lớn (`textScaleFactor` cao, accessibility setting phổ biến) hoặc màn hình rất hẹp, các `Text` này có thể tràn ra ngoài container cố định (36px height cho segment label, hoặc list tile 1 dòng) — gây lỗi layout `RenderFlex overflow` thấy được bằng mắt (vệt vàng-đen kinh điển của Flutter) trên máy thật.

## Vì sao cần / Hậu quả
Người chơi bật accessibility "phóng to chữ" (rất phổ biến, không phải edge case hiếm) sẽ thấy lỗi overflow thị giác ở đúng những widget hiển thị số liệu quan trọng nhất (streak, tab, tên item) — ảnh hưởng trực tiếp tới nhóm người dùng cần accessibility nhất.

## Đề xuất
`SegmentedTabBar`: bọc label trong `FittedBox(fit: BoxFit.scaleDown)` hoặc thêm `maxLines: 1, overflow: TextOverflow.ellipsis`. `StreakCounter`: bọc số ngày trong `Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(...)))` giống hệt cách `CurrencyCounter` đã làm (tái dùng đúng pattern đã có trong kit, không phát minh cách mới). `CommonListTile`: thêm `overflow: TextOverflow.ellipsis` cho `title`/`subtitle`.

## Acceptance criteria
- [ ] 3 widget trên không còn overflow ở textScaleFactor cao (test với 2.0-3.0) hoặc container hẹp bất thường (ví dụ 100px width).
- [ ] Test: pump mỗi widget với MediaQuery textScaler phóng to và/hoặc SizedBox hẹp, xác nhận tester.takeException() rỗng (không có RenderFlex overflow error) và text vẫn hiển thị (không bị ẩn hoàn toàn).
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-40-text-overflow-protection-sweep.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — bug thị giác thật có thể tái hiện dễ dàng (chỉ cần đổi textScaleFactor), effort thấp vì chỉ áp dụng lại pattern đã có sẵn trong kit (CurrencyCounter).
