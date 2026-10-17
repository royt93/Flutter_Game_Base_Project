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
- [ ] **Unit test**: Validate id/name không rỗng, slotId duy nhất, `maxSlots > 0`; tính create-enable khi slot count < maxSlots.
- [ ] **Widget test**: Select/create callbacks; limit khóa Create; delete cancel không gọi callback, confirm gọi đúng slotId; active row, empty/loading/error, semantics; Reduced Motion.
- [ ] **Integration test (Device)**: Pixel 7 Pro list/select/create/delete slot qua `SaveSlotManager` thật và storage thật, xác nhận active slot/data metadata.
- [ ] **Golden test**: Ma trận row active/inactive, empty, delete confirm trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Rời màn hoặc app pause trong confirm sheet; không gọi delete/create hai lần, state không stale khi resume.
- [ ] **Network conditioning test**: N/A — `SaveSlotManager` local-only; cloud save seam ngoài phạm vi widget.
- [ ] **Memory leak & profiling test**: Lặp mount/unmount và mở/đóng confirm; MemoryWatchdog không báo orphan controller/overlay/timer.
- [ ] **Frame rate / Jank test**: Profile scroll list 10+ slots + open/close confirm, báo p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A — slot management không mua hàng/không hiển thị ad.

## Hiệu năng & Animation
- [ ] Dùng `ListView.builder` khi danh sách lớn; lazy render, tránh tạo controller cho row ngoài viewport.
- [ ] Sustained 60 FPS benchmark: đo workload scroll/update slot trên thiết bị vật lý thật.
