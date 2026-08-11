# T3 — Lỗ test còn lại ở tầng data/logic

**Epic:** E7 Test coverage · **SP:** 3 · **Pri:** Should · **Deps:** —
**Trạng thái:** ✅ Done (2026-08-11)

## Vấn đề
Tầng `lib/logic` + `lib/data` là tầng thuần Dart, không Flutter — rẻ nhất để
test và CLAUDE.md yêu cầu mọi thay đổi logic phải kèm test ở đây. Còn 6 file
chưa có test tương ứng:

| File | Vì sao đáng test |
|---|---|
| `logic/wildcard_tile.dart` | wildcard khớp **mọi** màu trong flood-fill nhưng **không** được nối 2 nhóm khác màu — đây là quy tắc tinh tế, dễ vỡ khi sửa `pop_detector` |
| `data/pigments.dart` | có `assert` rằng free / coin-priced / achievement-gated là **loại trừ nhau**; assert chỉ chạy ở debug, test mới là thứ bảo vệ thật |
| `data/mascot_skins.dart` | `unlockAchievementId` phải trỏ tới achievement **có thật** trong `kAchievements`; id sai làm skin không bao giờ mở được |
| `data/leaderboard_bots.dart` + 3 bảng bot khác | điểm bot phải phủ dải hợp lý để người chơi không luôn hạng 1 hoặc luôn bét |

## Vì sao Should (không Must)
Không có bug đã biết ở các file này. Đây là phòng ngừa, và giá trị thật nằm
ở 2 case đầu (wildcard: quy tắc gameplay tinh tế; pigments: invariant đang
chỉ được bảo vệ bằng `assert`).

## Acceptance criteria
- [x] `test/logic/wildcard_tile_test.dart` (15 case): wildcard khớp mọi màu;
      **không** bắc cầu 2 nhóm khác màu; tap thẳng vào wildcard kế thừa màu
      hàng xóm; wildcard cô lập không tạo nhóm pop được.
- [x] `test/data/pigments_test.dart` (14 case): mọi pigment thoả đúng 1 trong
      3 dạng mở khoá; mọi `unlockAchievementId` tồn tại; id không trùng. Kèm
      round-trip `encode/decodeGemColorOverrides`.
- [x] `test/data/mascot_skins_test.dart` (11 case): `unlockAchievementId` tồn
      tại; skin đầu bảng free; id không trùng; mỗi skin palette riêng.
- [x] `test/data/leaderboard_bots_test.dart` (45 case): cả 4 bảng bot — không
      rỗng, điểm giảm dần nghiêm ngặt, phủ dải đủ rộng, và `buildLeaderboard`
      xếp hạng đúng ở 3 mốc điểm người chơi.
- [x] Toàn bộ test mới là thuần Dart, không cần widget harness.

## Đã làm
**85 test mới**, 4 file. Suite: 882 → **967 pass**. Không sửa dữ liệu nào —
mọi invariant đã đúng sẵn, test chỉ khoá chúng lại.

Gộp 4 bảng bot vào 1 file dùng chung một bộ kiểm (theo đúng ghi chú của task),
thay vì 4 file na ná nhau. Thêm 2 kiểm liên-bảng ngoài AC: 4 bảng không vô
tình trỏ chung một list, và thang điểm campaign (tổng sao) thấp hơn hẳn thang
điểm theo ván — trộn nhầm 2 nhóm này là lỗi âm thầm, bảng vẫn hiện nhưng vô
nghĩa.

## Sửa test, không sửa code
Test đầu tiên cho wildcard cô lập assert `isEmpty` và **đỏ**. Đọc lại doc của
`findConnectedGroup` thì hợp đồng ghi rõ: không mượn được màu thì trả nhóm
**kích thước 1**, không phải rỗng. Code đúng, test tôi viết sai — đã sửa test
và ghi rõ vì sao hành vi đó vô hại (`_tryPop` bỏ mọi nhóm < 2).

## Kiểm chứng
| Bơm lỗi vào production | Kết quả |
|---|---|
| Đổi `unlockAchievementId` của pigment sang id không tồn tại | đỏ |
| Cho skin đầu bảng một `coinPrice` | đỏ |
| Bỏ điều kiện màu trong flood-fill (wildcard bắc cầu) | 6 đỏ |

## Phát sinh: [[T5]]
Định thêm `test/core/utils/clamped_clock_test.dart` (file thêm ở [[X22]],
chống gian lận đồng hồ, chưa có test riêng) nhưng **không viết được**:
`Get.put(StorageService(...))` trong async helper mất đăng ký qua async gap.
Các test khác không dính vì chúng `Get.put(GameController())` ngay sau, và
`onInit` của nó gọi `StorageService.to` trước async gap.

Đã **bỏ file đó** thay vì hack quanh (workaround "gọi `Get.find` cho chắc" là
loại code không ai dám xoá sau này), và mở [[T5]] kèm nội dung test đã phác
thảo sẵn. `clamped_clock` hiện vẫn được cover gián tiếp qua
`raid_boss_controller_test`.

## Ghi chú
`test/data/` đã có 17 file cùng dạng — chép khuôn từ `achievements_test.dart`
hoặc `board_frames_test.dart`, chúng test đúng loại invariant này.

Không cần test cho `daily_challenge_leaderboard_bots.dart` /
`gauntlet_leaderboard_bots.dart` / `weekly_featured_leaderboard_bots.dart`
riêng lẻ — gộp cả 4 bảng vào 1 file test dùng chung một hàm kiểm tra, chúng
có cùng hình dạng dữ liệu.

DoD chung: `../README.md`.
