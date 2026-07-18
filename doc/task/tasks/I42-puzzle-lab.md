# I42 — Puzzle Lab (level editor + chia sẻ mã bàn tự chế)

**Epic:** Gameplay depth (big feature) · **SP:** 13 · **Pri:** Could · **Deps:** không

## Mục tiêu
Cho người chơi tự vẽ 1 bàn tuỳ ý (kích thước, số màu, vị trí obstacle/gift
tile) trong 1 màn editor mới, lưu tối đa vài bàn cục bộ, và xuất ra 1 "mã
puzzle" (base64url, giống `encodeReplay`/`I37`) để chia sẻ cho bạn bè. Người
nhận nhập mã → chơi đúng bàn đó qua `PopStarGame(presetGrid: ...)` (hạ tầng
đã có sẵn, dùng cho test hiện tại), không tính vào tiến độ campaign.

## Vì sao
`PopStarGame` đã nhận `presetGrid` (`List<List<int>>?`) từ trước (dùng nội bộ
cho test xác định) nhưng chưa có đường nào cho người chơi thật tự tạo nội
dung. Đây là "user-generated content" rẻ nhất có thể làm mà KHÔNG cần backend
(đúng chủ trương dự án) — mã hoá bàn thành text, chia sẻ qua kênh ngoài app
(tin nhắn, QR như `F15`/`I28`), không cần server lưu trữ.

## Acceptance criteria
- [ ] `lib/logic/puzzle_code.dart` (mới): hàm `encodePuzzleGrid(List<List<int>> grid)`
      / `decodePuzzleGrid(String code)` — mã hoá `rows|cols|v1,v2,...` (giá
      trị mỗi cell nối bằng dấu phẩy, hàng nối bằng `;`), base64url giống
      `encodeReplay`. Validate khi decode: kích thước khớp `rows*cols`, giá
      trị màu trong khoảng hợp lệ (0..11, xem `colorCount` tối đa ở
      `lib/data/levels.dart`), obstacle/gift/boss id âm hợp lệ theo đúng dải
      đã định nghĩa (`giftTileValue`, `bossTileIdBase`, obstacle range) —
      trả `null` nếu bất kỳ điều kiện nào sai (chống mã giả mạo/hỏng).
- [ ] `lib/presentation/screens/puzzle_lab_screen.dart` (mới): grid editor
      cơ bản — chọn rows/cols (giới hạn trong khoảng đã dùng cho campaign,
      6-12 cột / 8-11 hàng theo `CLAUDE.md`, tránh bàn quá khổ gây lỗi render),
      chọn số màu, tap từng cell để gán màu/obstacle/gift/trống theo vòng
      lặp giá trị. Nút "Lưu" (tối đa N bàn cục bộ, ví dụ 5, lưu qua
      `SharedPreferences` dạng JSON list mã puzzle) và "Chia sẻ mã".
- [ ] `StorageKeys.savedPuzzles` (mới) — list mã đã lưu, giới hạn số lượng
      (cắt bớt bàn cũ nhất khi vượt ngưỡng, không cho lưu vô hạn).
- [ ] Màn nhập mã (tái dùng UI nhập mã chung với `I37`/`I28` nếu đã có 1 ô
      nhập mã tổng quát nhận diện loại mã; nếu chưa, tạo 1 field nhập text
      + nút "Chơi bàn tuỳ chỉnh"): decode thành công → mở `PopStarGame`
      với `presetGrid` tương ứng, `targetScore` mặc định tính theo công thức
      chung `cells * 6` (không có `ramp` theo world vì đây không thuộc world
      nào, xem `lib/data/levels.dart`), không cộng vào `unlockedLevel`/high
      score campaign.
- [ ] Kết quả chơi bàn tự chế KHÔNG gọi `checkEnd` campaign bình thường (tự
      viết 1 nhánh kết thúc riêng nhẹ — chỉ hiện điểm đạt được, không
      thưởng coin/star/unlock level kế, tránh người chơi lách target
      achievability bằng bàn tự vẽ dễ).
- [ ] i18n đủ 22 locale cho toàn bộ UI editor + màn chơi bàn tự chế.
- [ ] Test pure: `encodePuzzleGrid`/`decodePuzzleGrid` round-trip đúng cho
      bàn có đủ gem thường + obstacle + gift + boss tile; mã hỏng/kích thước
      không khớp/giá trị màu ngoài phạm vi → `null`; bàn rỗng toàn `null`
      (không có gem nào) vẫn encode/decode được nhưng validate riêng chặn
      chơi bàn không có gem nào (không thể pop được gì).
- [ ] Test widget: `PuzzleLabScreen` tạo bàn cơ bản, lưu, xuất mã không lỗi;
      nhập mã lỗi hiện thông báo rõ ràng, không crash.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- Đây là task lớn nhất trong đợt (SP 13) — nên chẻ nhỏ khi implement thật:
  (1) `puzzle_code.dart` pure logic + test trước, (2) editor UI cơ bản
  (không cần đẹp ngay), (3) luồng chơi bàn tự chế + kết quả riêng, (4) share/
  nhập mã cuối cùng.
- `presetGrid` hiện chỉ dùng nội bộ cho test xác định RNG (xem
  `test/widget/replay_determinism_test.dart`) — cần xác nhận `PopStarGame`
  vẫn hoạt động đúng khi `presetGrid` đến từ người dùng thật (không phải test
  cố định), đặc biệt validate không có giá trị int rác lọt vào grid.
- Không mã hoá `isReplay`/RNG cho puzzle — bàn tự chế là preset cố định,
  không cần random gì thêm ngoài chính nội dung đã vẽ.

DoD chung: `../README.md`.
