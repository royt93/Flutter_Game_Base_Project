---
id: BUG-141
title: "VersionedJsonStore: save không đọc được bị ghi đè im lặng bởi save() kế tiếp"
type: bug
layer: lib/core
priority: P1
effort: S
source: "Chaos survey 2026-11-23 (test chạy thật, đã xoá)"
---

## Bằng chứng (đo bằng test tạm trên VM)

`load()` trả `null` khi save không dùng được (đúng chính sách BUG-20), raw trong storage còn nguyên. Nhưng game thấy `null` như "máy mới", tạo save mặc định và gọi `save()`, ghi đè raw cũ:

| Tình huống | raw trước | sau `save({'coins': ...})` |
|---|---|---|
| A: JSON hỏng/cụt `{"coins": 9999, "bro` | còn nguyên | `{"coins":0,"schemaVersion":1,...}` |
| B: migrate ném giữa chừng (step 2->3) | còn nguyên | `{"coins":0,"schemaVersion":3,...}` |
| C: registry thiếu hop (không có 2->3) | còn nguyên | bị ghi đè khi save |
| D: save từ phiên bản MỚI hơn (schemaVersion 99, coins 777) | còn nguyên | `{"coins":1,"schemaVersion":1,...}` |

D là kịch bản thật: người chơi hạ app (hoặc cài bản cũ), chơi một ván, mất save phiên bản mới.

## Đề xuất (cần owner chọn)

Trước khi `save()` ghi đè một raw không đọc được: (a) sao lưu sang `<key>.bak` / `<key>.unreadable` (một bản, không phình), hoặc (b) từ chối `save()` với `SdkFailure` và để game quyết định. (a) không đổi hợp đồng `save()`; (b) an toàn hơn nhưng game cũ phải xử lý lỗi.

## Cần có khi làm

- Test cho 4 tình huống trên (raw cũ vẫn khôi phục được sau save).
- Ghi **Behavior change** vào CHANGELOG nếu đổi hợp đồng.
- Kiểm `SaveSlotManager`, `SeasonEventService`, các service dùng `VersionedJsonStore` không bị ảnh hưởng.
- Chưa phủ trong survey: field sai kiểu bên trong `fromJson` (đã có `loadResult()`), slot metadata trỏ payload thiếu.

## Kết quả thực hiện (2026-11-23)

- Chọn phương án sao lưu `.bak` (owner chọn). `VersionedJsonStore.save()` và nhánh `syncWith` thay bản local bằng cloud gọi `_backupIfUnreadable()`: raw hiện có nhưng `_readLocalJson()` trả null thì chép sang `backupKey` (`<key>.bak`), một bản. Save đọc được không bao giờ sao lưu; lần save đầu không tạo `.bak`.
- Test: 6 test mới trong `versioned_json_store_test.dart` (schema mới hơn, JSON hỏng, migrate ném, save đọc được không backup, save đầu không backup, cloud thay local không đọc được). Mutation (bỏ ghi `.bak`) làm 4 test đỏ.
- Phát hiện khi làm: bản đầu dùng `await` vô điều kiện trong `save()` làm 7 test đỏ (daily_login, achievement, seeded_challenge) vì chúng dựa vào lượt ghi bắt đầu đồng bộ; đã sửa để chỉ await khi cần backup.
- Khôi phục (bổ sung cùng ngày): `hasBackup`, `loadBackup()` (đi qua cùng chính sách schema như `load()`: cũ được migrate, mới hơn/hỏng bị từ chối), `restoreBackup()` (ghi đè save hiện tại bằng bản backup rồi xoá backup; trả `false` và không đổi gì nếu backup chưa dùng được). 4 test mới gồm vòng downgrade thật (app cũ backup save v99, app mới khôi phục); mutation (không xoá backup) làm 1 test đỏ. API gate: 2 export mới, snapshot đã cập nhật.
- Chưa làm: UI khôi phục trong example; `restoreBackup` chưa hỏi người chơi, game tự xác nhận.
- Root 4132 + example 472 pass, analyze sạch, API gate unchanged (thêm `backupKey`), 5 quality-gate tool pass. CHANGELOG `## Unreleased` có Behavior change.
