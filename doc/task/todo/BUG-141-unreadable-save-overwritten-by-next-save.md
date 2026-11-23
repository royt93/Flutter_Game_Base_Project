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
