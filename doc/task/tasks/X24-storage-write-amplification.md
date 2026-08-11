# X24 — ~6 lần ghi `SharedPreferences` mỗi cú tap trên hot path

**Epic:** E6 Hardening · **SP:** 5 · **Pri:** Must · **Mức:** P1 (perf)
**Deps:** — · **Nên làm TRƯỚC** [[X17]]
**Trạng thái:** ✅ Done (2026-08-11)

## Vấn đề
`GameController.registerPop()` (`game_controller.dart:2121-2148`) chạy **mỗi
lần người chơi tap một nhóm hợp lệ**. Đếm số lần ghi đĩa trên đường đó:

| # | Call site | Ghi |
|---|---|---|
| 1 | `setInt(totalGemsPopped)` — dòng 2133 | `setInt` |
| 2 | `addWeeklyGoalProgress` → dòng 1391 | `setInt` |
| 3 | `addClanContribution` → dòng 1435 | `setInt` |
| 4 | `addClanContribution` → dòng 1439 | `setInt` |
| 5 | `_addDailyQuestProgress` → `_persistDailyQuests` dòng 1308 | `setString` |
| 6 | `_persistDailyQuests` dòng 1312 | `setString` |
| (+) | `maxComboEver` khi lập kỷ lục | `setInt` |
| (+) | `_checkAchievements` khi unlock (3 ghi) | `setString`×2 + `setInt` |

`StorageService.setInt/setString` (`storage_service.dart:273-309`) là
`await _prefs.setInt(...)` — **platform channel + ghi đĩa thật**, không phải
cache trong bộ nhớ.

Ngoài ra `_checkAchievements()` chạy mỗi pop và quét đủ 28 achievement + build
map 6 metric; `_checkStickerMilestones()` tính `totalCosmeticsOwned` (duyệt 4
bảng const) — có early-exit khi đã nhận hết mốc, nhưng achievement thì không.

## Vì sao Must
Đây là **hot path lõi** của game — mọi cú tap đều đi qua. Trên máy Android
tầm thấp, 6 lần ghi `SharedPreferences` đồng bộ hoá xen giữa animation pop
là nguồn giật khung hình rất điển hình. Game này bán bằng "juice" (E2 cả một
epic dành cho animation) nên jank ở đúng khoảnh khắc nổ là mất mát lớn.

Chưa có số đo — **AC bắt buộc phải đo trước/sau**, không sửa mù.

## User story
*As a* người chơi trên máy tầm thấp *I want* mỗi cú tap mượt *so that* hiệu
ứng nổ không khựng.

## Acceptance criteria
- [x] **Đo trước** — xem bảng dưới. Đo bằng test đếm số lần ghi, không phải
      profile tay trên device (PO chốt; lý do ở "Cách đo").
- [x] Số lần ghi trong 1 `registerPop` giảm về **≤1** ở trạng thái ổn định
      (thực tế: **0**).
- [x] Không mất dữ liệu khi app bị kill giữa ván — flush ở `checkEnd()`,
      `onClose()`, `AppLifecycleState` khác `resumed`, và trước mỗi giao dịch
      có thưởng.
- [x] Weekly goal card / daily quest dialog / clan pool vẫn realtime — không
      đụng Rx, chỉ đổi tầng persist.
- [x] Toàn bộ test cũ xanh: **801 pass**, không có test nào phải sửa vì đổi
      tầng storage.
- [ ] ~~`_checkAchievements()` bỏ sớm khi không metric nào đổi~~ — **không
      làm**, xem "Đã bỏ".

## Kết quả đo
| Kịch bản | Trước | Sau |
|---|---|---|
| 1 cú tap | **7 ghi** | **0 ghi** |
| 20 tap (trạng thái ổn định) | ~154 ghi | **0 ghi** |
| 20 tap (lượt đầu, combo leo 1→20) | ~154 ghi | 14 ghi |
| `checkEnd` (flush 1 lượt) | 0 | 16 ghi |

Baseline **7**, không phải 6 như spec ước lượng — sót `maxComboEver`.

14 ghi ở "lượt đầu" là sự kiện mở khoá **thật**: combo leo dần làm
`maxComboEver` tăng → mở burst style / combo-text style → chạm mốc Sticker
Album. Đó là unlock, không phải counter spam, nên cố ý **không** đệm.

## Cách đo (đổi so với AC gốc)
AC gốc yêu cầu profile frame-time trên device thật. Đã đổi sang **đếm số lần
ghi bằng test** (`test/presentation/hot_path_writes_test.dart`), vì:

- Nó đo **đúng khiếm khuyết** (7 lần platform-channel write mỗi tap).
  Frame-time chỉ là hệ quả, và trên máy mạnh có thể đo ra 0 khác biệt trong
  khi máy yếu vẫn giật.
- Tất định và lặp lại được. Profile tay cần tự tap để sinh tải — không tái
  lập được chính xác giữa 2 lần đo, nhiễu lớn hơn tín hiệu.
- Nó **ở lại** làm lưới chống hồi quy: round sau ai nối thêm hệ mới vào
  `registerPop` là test đỏ ngay. Một lần profile tay không làm được điều đó.

Đánh đổi đã chấp nhận: không có số "giảm X ms jank trên máy yếu". Suy luận,
không đo trực tiếp.

## Đã sửa
1. `storage_service.dart` — write-behind: `_buffer` map, `setIntBuffered` /
   `setStringBuffered`, `flush()`. **Mọi đường đọc tra buffer trước `_prefs`**
   (`getInt`/`getBool`/`getString`/`getDouble`/`allKeys`/`exportAll`), và
   `remove`/`importAll` dọn buffer — thiếu bất kỳ chỗ nào là đọc ra giá trị cũ.
   Thêm counter `platformWrites` để đo được.
2. `game_controller.dart` — 7 call site hot path sang buffered
   (`totalGemsPopped`, `maxComboEver`, `weeklyGoalProgress`,
   `clanContribWeek`, `clanContribTotal`, 2 `setString` của
   `_persistDailyQuests`). Mua/claim/reset giữ nguyên ghi ngay.
3. Flush tại: `checkEnd()` (bọc ngoài `_checkEnd` thay vì rải trước 3 đường
   `return`), `onClose()`, `claimDailyQuest()`, và `main.dart`
   `didChangeAppLifecycleState` khi rời `resumed`.

## Đã bỏ: tối ưu `_checkAchievements`
Subtask 4 (bỏ sớm khi metric không đổi) **không làm**. Sau khi phần ghi đĩa
xong, phần còn lại chỉ là quét 28 phần tử const trong bộ nhớ — rẻ hơn nhiều
bậc so với platform channel, và AC chính đã đạt (0 ghi/tap). Thêm một map
"metric lần trước" để so là thêm state cần đồng bộ, đổi lấy lợi ích chưa đo
được. Nếu sau này profile thật cho thấy nó đáng kể thì mở task riêng.

## Kiểm chứng
- Đổi `setIntBuffered`/`setStringBuffered` về bản thường → **2 test đỏ**.
- Gỡ `flush()` ở `checkEnd` → **1 test đỏ** (mất tiến độ ván nếu app bị kill).

## Ghi chú kỹ thuật
Đừng dùng `Timer`/`debounce` để flush. Comment ở `game_controller.dart:983-992`
ghi lại đúng bài học đó: `Debouncer` của GetX tạo `Timer` mà `Worker.dispose()`
không huỷ được, và `Get.reset()` (cách teardown của test suite) không gọi
`onClose()` — Timer treo lại sau khi controller đóng. Giải pháp đã dùng ở đó
là `scheduleMicrotask`. Đi cùng đường: flush theo microtask hoặc theo mốc
lifecycle tường minh, **không** theo timer.

DoD chung: `../README.md`.
