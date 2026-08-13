# X32 — Chain lock rò vào side mode qua phép chia lấy dư trên id âm

**Epic:** E6 Hardening · **SP:** 1 · **Pri:** Should · **Mức:** P2
**Deps:** — · **Phát hiện bởi:** verify [[F18]] trên máy thật
**Ảnh hưởng:** [[I44]] Mirror Mode · [[F18]] Board of the Day
**Trạng thái:** ✅ Done (2026-08-13)

## Bug

`PopStarGame._placeChainLocksIfNeeded` chốt bằng đúng một dòng:

```dart
if (level.id % 6 != 0) return;
```

Đây là nhịp của **campaign** (cứ 6 màn một lần). Nhưng `%` trong Dart trả 0 với
cả số âm, nên mọi side mode có id chia hết cho 6 lọt qua cổng:

| Mode | id | Hậu quả |
|---|---|---|
| `mirrorMode` | -6 | 2 ô khoá đặt **ngẫu nhiên** → phá tính đối xứng, vốn là toàn bộ lý do mode tồn tại |
| `puzzleDaily` ([[F18]]) | -18 | sửa bàn người chơi **tự vẽ** |

`world = (id - 1) ~/ 20` với id âm cho 0, nên `count = 2`, `lockValue = 1` —
đủ để hỏng ván nhưng đủ nhỏ để không ai để ý.

## Cách phát hiện

Không phải từ test. Build F18 lên máy, mở "Bàn hôm nay", và bàn preset
`corners` hiện ra với **2 ô khoá** mà preset không hề có. Đây đúng là loại lỗi
chỉ nhìn tận mắt mới thấy: mọi test đều xanh vì không test nào kiểm "bàn side
mode phải giống hệt bàn đã khai báo".

Mirror Mode đã mang lỗi này từ lâu, F18 chỉ là thứ làm nó lộ ra.

## Đã sửa

Thêm chốt `if (level.id <= 0) return;` **trước** phép chia lấy dư — cùng khuôn
`_placeWildcardTileIfNeeded` đã dùng. Các placer còn lại chốt bằng `id <= 60`
nên tự loại số âm.

## Kiểm chứng

- `test/game/side_mode_tile_injection_test.dart` — 5 ca dựng engine **thật**
  rồi đếm ô khoá: Mirror Mode, Board of the Day, và một ca quét **cả họ** side
  mode (id mới thêm sau này mà chia hết cho 6 sẽ đỏ ngay). Hai ca ngược chiều
  chốt rằng campaign **vẫn** có chain lock ở màn 6 và **không** có ở màn 7 —
  bản sửa không được tắt luôn cơ chế.
- **Mutation-check 2/2 bị bắt:** gỡ chốt `id <= 0`; tắt hẳn chain lock.
- Verify lại trên emulator sau khi sửa: bàn preset sạch, 4 góc màu đúng.
- Toàn bộ suite: **1407 xanh**.

## Bài học

Chốt điều kiện bằng phép chia lấy dư trên một id có thể âm là bẫy im lặng.
Trong repo này id âm là **quy ước** của mọi side mode, nên mọi `% n` áp lên
`level.id` phải có chốt dấu đứng trước.
