# I18 — Colorblind neon symbols

**Epic:** Neon/Glow độc quyền · **SP:** 5 · **Pri:** P2 · **Deps:** none

## Mục tiêu
Vẽ thêm icon/symbol riêng theo `colorIndex` lên mỗi gem (star/circle/triangle/square/diamond/hexagon/cross), bật/tắt qua Settings, giúp người dùng mù màu phân biệt gem không chỉ dựa vào màu.

## Vì sao
Board tối đa 7 màu (`colorCount` 4..7 theo world) — người mù màu (đặc biệt đỏ-lục) khó phân biệt 1 số cặp màu neon liền kề, không có fallback thị giác nào khác ngoài màu sắc.

## Acceptance criteria
- [ ] Có 7 symbol cố định ánh xạ 1-1 với `colorIndex` 0..6, phân biệt rõ ở kích thước nhỏ (block trong lưới 6-12 cột)
- [ ] Toggle "Colorblind mode" trong `SettingsScreen`, persist qua `SharedPreferences` bằng key mới trong `StorageKeys`
- [ ] Khi bật: mọi `BlockComponent` vẽ thêm symbol đè lên màu nền; khi tắt: giữ nguyên hiện trạng (không vẽ gì thêm)
- [ ] Không ảnh hưởng hitbox/tap logic của `BlockComponent` (symbol chỉ là lớp vẽ, không đổi kích thước/toạ độ)
- [ ] `flutter analyze` 0 lỗi

## Subtasks (gợi ý file)
- `lib/core/storage_service.dart` — thêm `StorageKeys.colorblindMode`.
- `lib/presentation/screens/settings_screen.dart` — thêm `SwitchListTile` theo đúng pattern `audioMuted` đang có (dòng ~33-35).
- `lib/game/block_component.dart` — thêm nhánh vẽ symbol theo `colorIndex` khi flag bật (đọc flag qua `StorageService.to` hoặc truyền xuống từ `PopStarGame`).
- Test widget: bật flag, render `BlockComponent`/`GameScreen`, xác nhận không crash và (nếu khả thi kiểm tra qua golden test) symbol xuất hiện.

## Ghi chú kỹ thuật
Dùng `CustomPainter`/`Path` vẽ symbol đơn giản (không cần asset ảnh, giữ đúng tinh thần vector-neon của `NeonTheme`) — tránh thêm font icon hay package mới khi 7 hình dạng cơ bản vẽ tay bằng `Canvas` là đủ.

DoD chung: ../README.md.
