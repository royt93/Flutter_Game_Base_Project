# I62 — Color Alchemy Lab

**Epic:** Cảm giác/A-V (cosmetic) · **SP:** 3 · **Pri:** Could
· **Deps:** I22 (Achievements)

## Mục tiêu

Cho phép người chơi "pha chế" bộ màu gem riêng (pigment set) mở khoá qua
achievement/coin, thay thế bảng màu neon mặc định trên toàn bộ bàn chơi —
thuần cosmetic, không ảnh hưởng luật match.

## Vì sao

`NeonTheme.gemColors` hiện là bảng màu cố định duy nhất cho mọi người
chơi — Color Alchemy Lab mở thêm chiều cá nhân hoá thị giác (giống board
frame/mascot skin đã có) mà chưa hệ thống nào trong game khai thác riêng
cho màu gem.

## Acceptance criteria

- [ ] `lib/data/pigments.dart` mới — danh sách `Pigment` (mirror đúng
  pattern `MascotSkin`, `lib/data/mascot_skins.dart` dòng 35-56) với
  `coinPrice: int?`/`unlockAchievementId: String?` optional.
- [ ] `StorageKeys.gemColorOverrides` — map slot-index → pigment-id (lưu
  dạng chuỗi encode, theo pattern các key CSV/JSON khác trong
  `storage_service.dart`).
- [ ] Hàm mới `resolvedGemColor(int colorIndex)` — kiểm tra override
  trước, fallback về `NeonTheme.gemColors[colorIndex %
  NeonTheme.gemColors.length]` nếu không có override (giữ nguyên hành vi
  modulo hiện tại cho world >7 màu... thực tế tối đa 7 màu theo
  `levels.dart`). **Không sửa trực tiếp `NeonTheme.gemColors`** — giữ nó
  làm giá trị mặc định/fallback.
- [ ] Đổi hướng `block_component.dart` dòng 228 từ gọi thẳng
  `NeonTheme.gemColors[colorIndex % ...]` sang gọi `resolvedGemColor(colorIndex)`.
- [ ] Màn hình mới `color_alchemy_screen.dart` (UI pattern tương tự màn
  chọn frame của I51) để xem/chọn pigment sở hữu.
- [ ] **Không** sửa `Achievement` class (`lib/data/achievements.dart` dòng
  12-28) thêm loại thưởng mới — Pigment chỉ tham chiếu 1
  `unlockAchievementId` đã tồn tại sẵn, giữ scope nhỏ.
- [ ] **Không** đụng `pop_detector.dart`/logic match — đây thuần thay đổi
  hiển thị, `colorIndex` dùng để so khớp vẫn giữ nguyên, chỉ đổi màu vẽ.
- [ ] Unit test mở rộng/tạo `test/core/neon_theme_test.dart` cho
  `resolvedGemColor()`: có override → dùng override; không override →
  fallback đúng modulo cũ.
- [ ] i18n toàn bộ text màn Color Alchemy Lab, đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Đây là thay đổi hiển thị thuần (display-only) — `resolvedGemColor()`
  chỉ ảnh hưởng bước vẽ ở `block_component.dart`, không ảnh hưởng
  `colorGrid`/matching logic ở tầng `lib/logic/`.
- Giữ `NeonTheme.gemColors` làm nguồn màu mặc định/fallback thay vì sửa
  trực tiếp — tránh phá vỡ mọi nơi khác đang tham chiếu bảng màu gốc.

DoD chung: `../README.md`.
