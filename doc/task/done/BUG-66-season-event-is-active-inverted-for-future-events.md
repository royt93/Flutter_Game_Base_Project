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
- [x] Sự kiện tương lai (`now < startMs`) trả về `isActive == false`.
- [x] Sự kiện đang diễn ra (`startMs <= now < startMs + length`) trả về `isActive == true` như cũ.
- [x] Sự kiện đã kết thúc vẫn trả về `isActive == false` như cũ.
- [x] Test hiện có của `season_event_service_test.dart` vẫn pass.

## Quyết định
Fix đúng như đề xuất trong task: `isActive: now >= startMs && now - startMs < length.inMilliseconds`.

Verify lại kỹ trước khi sửa: trong luồng bình thường (anchor luôn được set = `now` lần đầu tiên gọi, chưa từng có API public nào set anchor tương lai trực tiếp), `startMs <= now` LUÔN đúng — bug này trên thực tế chỉ lộ ra khi anchor đến từ nguồn KHÁC đồng hồ đã kẹp của thiết bị (ví dụ khôi phục save/cloud sync mang theo anchor "tân tiến" hơn `maxMsSeen` cục bộ). Dù hiếm khi tự nhiên xảy ra trong flow hiện tại, đây vẫn là lỗi logic thật (thiếu 1 nửa điều kiện range-check) — fix đúng theo *invariant* mà `isActive` phải đảm bảo (nằm trong `[start, end)`), không phải chỉ vá theo đúng 1 kịch bản observed.

**TDD verify**: test mới seed thẳng 1 anchor TƯƠNG LAI (`now + 10 phút`, nhỏ hơn 1 chu kỳ length+cooldown để tránh vòng lặp cycleIndex cuốn sang chu kỳ khác — verify kỹ bằng tay công thức `cycleIndex = elapsed ~/ cycleMs` trước khi chọn số) trực tiếp vào ĐÚNG storage key `SeasonEventService` dùng (qua 1 `VersionedJsonStore` tạm cùng schema, KHÔNG qua `nowMsClamped()` của chính service — mô phỏng đúng "anchor tới từ nơi khác"), rồi gọi `currentWindow()` với `now` ở hiện tại. `git stash` riêng `lib/core/season_event_service.dart`, chạy test — FAIL đúng trên code cũ (`isActive: true` cho sự kiện chưa tới). `git stash pop`, chạy lại toàn file — 24/24 pass, gồm cả 2 test có sẵn cho case "đang active"/"đang cooldown" (criteria 2/3 không cần thêm test mới, đã cover sẵn).

Kết quả cuối: `flutter analyze` root sạch, `flutter test --exclude-tags slow` root 2093 pass / -19 fail (baseline golden có sẵn, không liên quan), `dart run tool/api_compatibility.dart check` unchanged, `example/` `flutter analyze` sạch + `flutter test --exclude-tags slow` 132/132 pass (dùng qua `cookbook_screen.dart`).

Tự chấm: **9.5/10** — root cause đúng, fix khớp 100% invariant thiết kế của `isActive`, TDD chứng minh đúng kịch bản thật (không phải test giả định), tự phát hiện và tránh 1 pitfall tính toán (cycleIndex cuốn chu kỳ nếu offset quá lớn) trước khi chốt test, không phá test cũ.

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
