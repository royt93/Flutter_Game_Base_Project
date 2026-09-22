---
id: BUG-66
title: "SeasonEventService.currentWindow báo isActive=true cho sự kiện CHƯA diễn ra (tương lai)"
type: bug
priority: P2
effort: XS
source: "agy (độc lập) — cần verify lại chính xác dòng trước khi implement"
---

## Vị trí
`lib/core/season_event_service.dart` — `currentWindow()`, biểu thức tính `isActive` (~dòng 158-171 theo mô tả agy: `isActive: now - startMs < length.inMilliseconds`).

## Hiện trạng
Với sự kiện chưa bắt đầu (`now < startMs`), `now - startMs` là số âm — luôn nhỏ hơn `length.inMilliseconds` (dương) — biểu thức `isActive` trả về `true` dù sự kiện còn chưa diễn ra.

## Vì sao cần / Hậu quả
UI/logic dựa vào `SeasonEventWindow.isActive` để quyết định hiện banner/mở tính năng sự kiện sẽ MỞ SỚM 1 sự kiện chưa tới ngày bắt đầu — sai lệch trực tiếp với ý định thiết kế (`currentWindow()`/`isActive` dùng để gate live-ops event theo đúng khung giờ).

## Đề xuất
Sửa điều kiện `isActive` thành `now >= startMs && now - startMs < length.inMilliseconds` (hoặc `now < startMs + length`), đảm bảo cả 2 chiều: chưa tới ngày bắt đầu VÀ chưa hết hạn.

## Acceptance criteria
- [ ] Sự kiện tương lai (`now < startMs`) trả về `isActive == false`.
- [ ] Sự kiện đang diễn ra (`startMs <= now < startMs + length`) trả về `isActive == true` như cũ.
- [ ] Sự kiện đã kết thúc vẫn trả về `isActive == false` như cũ.
- [ ] Test hiện có của `season_event_service_test.dart` vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-66-season-event-is-active-inverted-for-future-events.md` này trước khi làm. Đọc toàn bộ `lib/core/season_event_service.dart` và test hiện có — TỰ XÁC NHẬN lại đúng biểu thức/số dòng trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria (3 case: tương lai/đang diễn ra/đã kết thúc).
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (fix logic thuần, unit test đủ chứng minh).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — mô tả kỹ thuật cụ thể (biểu thức chính xác), chưa tự Read lại đúng dòng do khối lượng batch verify lớn. Người thực hiện tự xác nhận lại trước khi sửa. Không trùng task nào trong `doc/task/done/`.
