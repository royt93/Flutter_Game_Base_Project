# TC-12 — Release Gap Closure

**Phạm vi:** nhóm test bổ sung sau audit QC: lifecycle, update/migration, back stack, accessibility, localization, persistence, logcat, device matrix.
**Mức ưu tiên:** P0/P1 trước mọi release candidate.
**Điều kiện bắt buộc:** mọi case P0 phải kèm logcat sạch: không `FATAL EXCEPTION`, `AndroidRuntime`, `ANR`, `E/flutter`, `Failed assertion`, `RenderFlex overflowed`.
**Automation gate:** chạy `tool/release_device_gate.sh <adb-serial>` cho thiết bị thật trước khi ký release.

---

## TC-12-01 — Install / Update / Data Migration (P0)

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Cài bản release/debug cũ có progress: level unlock, stars, coins, boosters, side-mode records | Data cũ tồn tại trước update |
| 2 | Cài đè APK mới bằng `adb install -r` | App mở được, không force reset |
| 3 | Kiểm tra Home/Level Select | Unlock/stars/high score còn đúng |
| 4 | Kiểm tra Shop/booster/theme | Sở hữu và skin/theme đang dùng còn đúng |
| 5 | Kiểm tra Battle Pass/Season/Achievement/Collection/Temple/Tree/Card | Không mất hoặc nhân đôi reward |
| 6 | Kiểm tra shard migration nếu có data cũ | Chỉ migrate 1 lần, không farm xu sau restart |
| 7 | Đọc logcat | Không có crash/assertion/migration exception |

---

## TC-12-02 — App Lifecycle / Resume / Timer / Audio (P0)

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Đang chơi Campaign, bấm Home, chờ 30s, mở lại | Board/state giữ đúng, không tự lose/win |
| 2 | Đang chơi Rush, background 30s, resume | Timer behavior nhất quán, không nhảy âm, không crash |
| 3 | Đang chơi Survival, background 30s, resume | Tide không nhảy lỗi/overflow; nếu có tăng thì đúng thiết kế |
| 4 | Lock screen rồi unlock | App resume đúng route |
| 5 | Nhận cuộc gọi/notification overlay | Game không nhận input sai khi app inactive |
| 6 | Audio muted rồi background/resume | Muted state giữ đúng; BGM không phát chồng |
| 7 | Rời GameScreen về Home | Wakelock tắt, app không giữ màn sáng vô hạn |

---

## TC-12-03 — Android Back / Route Stack / Double Tap (P0)

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Từ Home, tap nhanh 5 lần nút Boss | Chỉ có 1 GameScreen được push |
| 2 | Tap nhanh 5 lần Play Campaign | Chỉ có 1 WorldMap/LevelSelect/Pregame/Game route |
| 3 | Trong GameScreen, bấm Android Back | Hiện confirm quit hoặc xử lý nhất quán, không thoát app đột ngột |
| 4 | Khi confirm quit mở, bấm Back | Overlay đóng hoặc giữ đúng, không kẹt input |
| 5 | Mở Settings/Shop/Guide rồi spam Back | Về Home đúng 1 lần, không màn đen |
| 6 | Đang result dialog, bấm Again nhiều lần | Chỉ restart 1 ván, mode không bị đổi |
| 7 | Dùng Recents chuyển app rồi Back | Stack vẫn đúng |

---

## TC-12-04 — Device / Layout / Accessibility Matrix (P0)

| # | Cấu hình | Kết quả mong đợi |
|---|----------|------------------|
| 1 | Tecno BG6 720x1612 DPR 2.0 | Home, GameScreen, Boss HUD, 13 cards không overflow |
| 2 | Samsung S24 Ultra | UI không quá nhỏ, animation không blank |
| 3 | Font scale 1.3x | HUD/dialog/card không cắt chữ quan trọng |
| 4 | Font scale 1.5x | Không crash; nếu wrap thì vẫn usable |
| 5 | Display size lớn nhất Android | Board vẫn vừa màn, booster bar scroll được |
| 6 | Landscape nếu OS cho xoay | App khóa/hiển thị nhất quán, không vỡ layout |
| 7 | Split screen / multi-window nếu device hỗ trợ | Không crash hoặc có behavior chấp nhận được |
| 8 | Theme dark/light hệ thống | App vẫn giữ neon theme, text contrast đủ |

---

## TC-12-05 — Localization Full Sweep 22 Locale (P1)

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Lần lượt chọn 22 ngôn ngữ trong Settings | App đổi locale ngay, không crash |
| 2 | Mở Home/Game/Shop/Guide/Settings mỗi locale | Không hiện raw key như `boss_title`, `btn_home` |
| 3 | Kiểm tra placeholder `@n`, `@c`, `@t` | Được thay thế đúng, không lộ placeholder sai |
| 4 | Arabic `ar_SA` | Text không mất ký tự, layout không overflow nghiêm trọng |
| 5 | Thai/Hindi/Bengali | Font render đủ glyph, không ô vuông |
| 6 | Restart app sau chọn locale | Locale đã chọn được giữ |

---

## TC-12-06 — World Map / Level Select / Story / Pregame Overlay (P1)

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Home -> Play ở view World Map | Map auto-scroll tới current level |
| 2 | Đổi sang grid view | Setting viewMode lưu, restart vẫn giữ |
| 3 | Đổi lại World Map | Map hiển thị đúng world badge/stars |
| 4 | Tap level có story trigger lần đầu | StoryOverlay hiện trước pregame/game |
| 5 | Skip/next story | Vào Pregame nếu có booster, hoặc GameScreen nếu không |
| 6 | Story đã xem, tap lại level | Không hiện story trùng nếu đã lưu |
| 7 | Có booster pregame, mở overlay rồi Back/Cancel | Không consume booster, không start game |
| 8 | Chọn booster pregame rồi start | Booster pending áp đúng 1 lần |

---

## TC-12-07 — Side Mode Records / Milestone Rewards (P1)

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Chơi Endless đạt best stage mới | Corner chip/best record cập nhật |
| 2 | Chơi Boss thắng stage cao hơn | Best stage boss cập nhật; thua không ghi record |
| 3 | Chơi Rush đạt score mới | Rush best cập nhật, result panel hiện best |
| 4 | Rhythm/Gravity/ColorRush/Soda/Labyrinth thắng | Win count/record tier tăng đúng |
| 5 | Đạt bronze/silver/gold milestone | Thưởng milestone cộng 1 lần duy nhất |
| 6 | Restart app | Records/tier vẫn giữ |
| 7 | Chơi Daily/Puzzle/Versus | Không ghi nhầm record nếu thiết kế không track |

---

## TC-12-08 — Economy Negative / Anti-Farm (P1)

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Không đủ xu mua booster/skin/theme/lives | Không trừ xu, hiện feedback thiếu xu |
| 2 | Tap nhanh nút mua 10 lần | Không mua âm xu, không duplicate ngoài số lần hợp lệ |
| 3 | Claim Battle Pass tier đã nhận | Không cộng lại |
| 4 | Claim Challenge Card đã nhận | Không cộng lại |
| 5 | Piggy chưa đủ điều kiện smash | Không cho claim hoặc feedback đúng |
| 6 | Piggy đủ điều kiện smash | Cộng saved đúng, reset về 0, restart vẫn 0 |
| 7 | Collection claim sticker | Không cộng xu nếu thiết kế hiện tại là collection-only |
| 8 | Side-mode reward lần 4+ trong ngày | Diminishing return áp dụng đúng |

---

## TC-12-09 — Reset Progress Full Sweep (P0)

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Tạo data ở mọi hệ: campaign, coins, boosters, shop, BP, season, achievement, collection, temple, tree, cards, records, daily, wheel | Data tồn tại |
| 2 | Settings -> Reset -> Cancel | Không data nào đổi |
| 3 | Settings -> Reset -> Confirm | Tất cả persistent + in-memory reset |
| 4 | Không restart, quay lại từng màn | UI đã fresh, không còn badge stale |
| 5 | Restart app | Fresh state vẫn giữ |
| 6 | Sau reset, chơi lại level 1 | Có thể earn/claim lại bình thường, không bị lock bởi flag cũ |

---

## TC-12-10 — Asset / Audio / Offline Robustness (P1)

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Mở app khi offline | App hoạt động đầy đủ nếu không cần network |
| 2 | Bật/tắt audio liên tục khi chơi | Không crash, không audio chồng |
| 3 | Combo lớn phát nhiều note nhanh | Không lag rõ, không audio exception |
| 4 | Vào Versus 2 board, audio muted internal | Không phát chồng âm 2 board |
| 5 | Kiểm tra assets splash/icon/font/audio bằng build release/debug | Không missing asset trong log |

---

## TC-12-11 — Performance / Soak / Memory (P1)

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Chơi Campaign 10 phút trên Tecno | Không ANR/crash, FPS chấp nhận được |
| 2 | Chơi Survival 10 phút | Tide/overlay không leak, memory không tăng bất thường |
| 3 | Chơi Versus 5 phút | 2 Flame boards không làm app bị kill |
| 4 | Mở/đóng 50 route Home -> screen -> Back | Không memory leak rõ, không duplicate controller |
| 5 | Tạo 20 combo lớn liên tiếp bằng debug/test board | Không freeze >2s |
| 6 | Đọc logcat cuối pass | Không có ANR, tombstone app, Flutter assertion |

---

## TC-12-12 — Store / Build Variant / Package Sanity (P1)

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Build debug APK | Pass |
| 2 | Build release APK/AAB | Pass |
| 3 | Cài release build lên device sạch | Launch được, đúng package `com.galaxyjoy.neon_jewels` |
| 4 | Kiểm tra version footer | Khớp `pubspec.yaml`/build number |
| 5 | Upgrade debug -> release hoặc release -> newer release nếu quy trình cho phép | Không mất data ngoài kỳ vọng |
| 6 | Kiểm tra app icon/splash trên launcher | Đúng brand, không icon default |
| 7 | Chạy `tool/release_device_gate.sh <serial>` | Build/install/launch/logcat gate pass |
