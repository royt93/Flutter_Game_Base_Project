# I29 — Star Boss Milestone Levels (multi-cell boss tile)

**Epic:** Gameplay depth · **SP:** 8 · **Pri:** Should · **Deps:** không

## Mục tiêu
Tại các level mốc (milestone — vd cuối mỗi world), thêm 1 "boss tile" chiếm
**thật nhiều cell liền kề** trên grid (ví dụ khối 2x2/2x3) như 1 khối duy
nhất có HP; người chơi phải pop group gem thường **liền kề** boss tile
nhiều lần để nó "nứt vỡ" dần rồi biến mất. Đây là **khái niệm hoàn toàn
khác** field `isBoss`/`bossTargetMultiplier` đã có sẵn (chỉ tăng target
score, không phải tile).

## Vì sao
User chọn phương án khó hơn (thay vì N-cell giả lập + combo-streak không
đổi grid): tile chiếm không gian thật trên bàn tạo cảm giác "con trùm" rõ
rệt hơn cho các mốc quan trọng, dùng cho milestone lớn (không phải mọi
level boss thường).

## Acceptance criteria
- [ ] Grid vẫn giữ kiểu `List<List<int?>>` — mỗi cell thuộc cùng 1 boss
      tile mang cùng 1 mã âm định danh instance (nối tiếp tiền lệ obstacle
      dùng số âm), cộng 1 cấu trúc riêng (ngoài grid) lưu HP + vị trí từng
      boss tile — không nhét HP vào giá trị int của grid.
- [ ] `findConnectedGroup` tiếp tục loại trừ cell boss khỏi flood-fill
      thường (đã đúng theo cách xử lý số âm hiện có) — boss tile không tap
      trực tiếp để pop như gem thường.
- [ ] Cơ chế "nứt vỡ": mỗi lần người chơi pop 1 group gem thường có ít nhất
      1 cell **liền kề 4 hướng** với boss tile, boss tile giảm 1 HP; khi HP
      về 0, toàn bộ cell của nó chuyển `null` rồi để
      `applyGravityAndCollapse` xử lý rơi/dồn bình thường (không đổi logic
      gravity/collapse).
- [ ] VFX: tái dùng `_BurstRing` (phóng to tại từng cell khi giảm HP, lớn
      hơn khi vỡ hẳn); có thể tái dùng `AuroraBgLayer` cho khoảnh khắc boss
      xuất hiện đầu level.
- [ ] Thêm field cấu hình placement boss tile cho level milestone (vị trí,
      kích thước khối, HP khởi đầu) — đặt tên **khác** `isBoss` để tránh
      nhầm lẫn (vd `bossTileSpec`), tách biệt hoàn toàn 2 khái niệm trong
      code lẫn comment.
- [ ] `hasAnyMovableGroup`/stuck-board: xử lý case bàn có boss tile chưa vỡ
      nhưng không còn gem thường liền kề pop được — có cơ chế chống kẹt
      (vd tự giảm HP dần theo thời gian, hoặc tính là "stuck" hợp lệ để
      trigger shuffle/end như bình thường).
- [ ] Logic giảm HP/vỡ tile tách thành hàm pure trong `lib/logic/` (test
      được không cần Flame/UI).
- [ ] i18n cho tutorial/thông báo giới thiệu boss tile.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- Grid hiện tại `List<List<int?>>`; số âm đã dùng cho obstacle/gift trong
  `lib/logic/pop_detector.dart` (flood-fill loại trừ) và
  `lib/logic/pop_collapse.dart` (gravity/collapse).
- Field `PopLevel.isBoss` + `bossTargetMultiplier = 1.5` trong
  `lib/data/levels.dart` là khái niệm **khác** (chỉ tăng target score) — có
  sẵn từ trước, **không** liên quan tile mới này. Phải đặt tên khác, ghi rõ
  comment phân biệt.
- VFX tái dùng: `_BurstRing` trong `lib/game/pop_star_game.dart`,
  `AuroraBgLayer` trong `lib/presentation/widgets/aurora_bg_layer.dart`.
- Đây là thay đổi đụng sâu nhất vào core grid trong 4 idea đợt này — nên
  review kỹ `pop_detector.dart`/`pop_collapse.dart` hiện tại trước khi sửa,
  viết test pure trước khi nối vào Flame layer.

DoD chung: `../README.md`.
