---
id: FEAT-143
title: SaveSlotPicker — Bộ chọn slot lưu game với active, tạo và xóa slot
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Retention, Monetization & Meta-Game UI (Wave 10)
---

## Vì sao cần
Game có nhiều nhân vật, chiến dịch hoặc hồ sơ cần cho người chơi chuyển đổi giữa nhiều save slot và tạo chiến dịch mới. `SaveSlotManager` đã quản lý metadata slot; package chưa có UI picker để liệt kê và kích hoạt slot, tạo slot, hoặc xóa slot có xác nhận.

## Đề xuất phạm vi
Widget `SaveSlotPicker` hiển thị:
- Danh sách `SaveSlot` metadata do caller cung cấp: slotId, name, lastPlayed, isActive.
- Slot đang dùng được làm nổi bật; mỗi row có action `Select` callback `onSelect(slotId)`.
- Nút `Create New` gọi `onCreate`; có thể disable theo `maxSlots` do caller truyền.
- Xóa slot mở `ConfirmDialog`/inline confirm có destructive action; callback `onDelete(slotId)` chỉ chạy sau xác nhận.
- Hiển thị trạng thái empty/loading/error từ props; widget không tự đọc/ghi `SaveSlotManager`.
- Presentation-only: caller nối `SaveSlotManager.listSlots/setActiveSlot/createSlot/deleteSlot`.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: Validate id/name không rỗng, duplicate id, timestamp âm và `maxSlots > 0`; create enable/disable theo capacity (`test/widget/common/save_slot_picker_test.dart`, 8 test pass).
- [x] **Widget test**: Select/create callbacks; limit khóa Create; delete cancel không gọi callback, confirm gọi đúng slotId; active row, empty/loading/error, semantics; Reduced Motion.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) chạy showcase thật: select inactive, create slot 3, xác nhận delete, capacity mở lại. Widget demo dùng state caller in-memory độc lập; `SaveSlotManager` thật có smoke `BUG-87` riêng (`app_boot_test.dart`). Không chạy tiếp thao tác device sau test vì trước khi rerun foreground check đã báo Play Console.
- [x] **Golden test**: `runGoldenMatrix` active/inactive rows trên light/dark/vi/RTL/textScale/reducedMotion (`save_slot_picker_golden_test.dart`). Empty state và delete-confirm matrix riêng chưa có.
- [x] **Interruption test**: unmount trong delete confirmation không ném lỗi; chưa kiểm chứng pause/resume thật hoặc stale state sau resume.
- [x] **Network conditioning test**: N/A — `SaveSlotManager` local-only; cloud save seam ngoài phạm vi widget.
- [ ] **Memory leak & profiling test**: CHƯA CHẠY MemoryWatchdog cho FEAT-143.
- [ ] **Frame rate / Jank test**: CHƯA ĐO list 10+ slots + confirm trên thiết bị.
- [x] **IAP & Ad mediation test**: N/A — slot management không mua hàng/không hiển thị ad.

## Hiệu năng & Animation
- [x] Dùng `ListView.separated` / `ListView.builder` lazy render; không tạo controller cho row ngoài viewport.
- [ ] Sustained 60 FPS benchmark: chưa đo, không tuyên bố đạt 60 FPS.

## Phạm vi demo
- [x] Showcase dùng state caller in-memory riêng, không ghi hoặc xóa save slot người chơi; các integration test service-backed kiểm thử `SaveSlotManager` riêng.
