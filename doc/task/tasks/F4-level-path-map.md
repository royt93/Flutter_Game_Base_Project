# F4 — Level path map + world theme

**Epic:** Features · **SP:** 8 · **Pri:** Should · **Deps:** — (làm ở Wave 5, nội dung lớn)

## Mục tiêu
Đổi Level Select từ grid phẳng sang **đường path uốn lượn** (node level nối bằng
đường), chia theo **10 world** (mỗi 20 màn) có tông màu/tên riêng.

## Vì sao
Cảm giác tiến trình là chuẩn casual (Candy Crush/Toon Blast). Grid phẳng đơn điệu.

## Acceptance criteria
- [ ] 200 node xếp theo đường uốn, scroll dọc mượt; node mở khoá/hoàn thành/khoá rõ.
- [ ] Node hiện sao đã đạt; node hiện tại nổi bật (pulse).
- [ ] Chia 10 world, mỗi world có banner tên + tông màu nền riêng.
- [ ] Auto-scroll tới màn cao nhất mở khoá khi vào.
- [ ] Widget test: render + tap node mở khoá vào game; node khoá không vào.

## Subtasks (gợi ý file)
1. `lib/data/levels.dart` hoặc `worlds.dart`: định nghĩa 10 world (tên, màu, range).
2. `lib/presentation/screens/level_select_screen.dart`: viết lại bằng `CustomScrollView`
   + `CustomPaint` vẽ đường nối; node = widget tile hiện có (tái dùng `_LevelTile`).
3. Layout path: hàm sinh vị trí node zig-zag theo index.
4. Auto-scroll: `ScrollController` tới node `unlockedLevel`.
5. i18n tên world. Test cập nhật `test/widget/`.

## Ghi chú kỹ thuật
Nặng nhất nhóm Features. Có thể chia 2 bước: (a) re-skin grid theo world-color +
banner (nhanh); (b) path uốn thật (sau). Giữ tái dùng `_LevelTile` để đỡ vỡ test.

DoD chung: `../README.md`.
