# TC-11 — Animation & Gameplay Smoke Matrix

**Phạm vi:** test animation, crash UI, và gameplay thật cho Home, Campaign, 13 challenge entries, result dialog, audio/haptic feedback.
**Mục tiêu:** phát hiện crash/render overflow/animation blank/stuck state khi chơi thực tế trên device.
**Thiết bị bắt buộc:** Samsung S24 Ultra hoặc Tecno BG6; test thêm 1 màn hẹp 720x1612 nếu có.
**Log bắt buộc:** trong lúc test chạy `adb logcat` và ghi lại `FATAL EXCEPTION`, `AndroidRuntime`, `E/flutter`, `RenderFlex overflowed`, `Failed assertion`.

---

## Checklist chung cho mọi animation

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Cold start app | Splash/Home vào ổn, không đen màn, không crash |
| 2 | Bấm từng button có glow/scale | Có feedback tap, không double navigate, không freeze |
| 3 | Chuyển Home -> gameplay -> Back/Home | Transition mượt, không giữ overlay cũ |
| 4 | Chơi 10 nước liên tục | Gem swap, clear, cascade, refill không giật/stuck |
| 5 | Tạo combo >= 2 | Combo text/particle/slow motion hiện rồi tự biến mất |
| 6 | Đợi 5 giây không chạm | Hint animation hiện, không che input |
| 7 | Kết thúc win/lose | Result dialog animate vào, nút Again/Home hoạt động |
| 8 | Xoay âm thanh mute/unmute nếu có | Icon đổi đúng, không crash khi AudioManager chưa init |
| 9 | Test font lớn hệ thống | Không overflow, không cắt chữ HUD/dialog |
| 10 | Đọc logcat sau session | Không có crash/assertion/RenderFlex overflow |

---

## TC-11-01 — Home Challenges Animation

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Mở Home trên màn hẹp | 13 challenge cards cùng size, không overflow |
| 2 | Quan sát corner chip record/daily/puzzle | Chip không đè text/icon chính |
| 3 | Tap nhanh 3 lần vào Boss/Rush/Zen | Chỉ mở 1 màn, không stack nhiều route |
| 4 | Back về Home từ từng mode | Home vẫn giữ layout 2 hàng cân đối |

---

## TC-11-02 — Campaign Core Gameplay

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Chọn Level 1 | Board load đầy đủ, HUD score/moves đúng |
| 2 | Swap không hợp lệ | Gem đảo lại, không trừ lượt |
| 3 | Match-3 hợp lệ | Gem clear, score tăng, lượt giảm 1 |
| 4 | Match-4 | Tạo special gem, animation nổi bật |
| 5 | Match-5 | Tạo rainbow/light ball, không mất input |
| 6 | Special + special | Clear area đúng, cascade ổn |
| 7 | Thắng level | Star animation + coin reward đúng |
| 8 | Thua level | Lose dialog hiện, mạng campaign trừ đúng |

---

## TC-11-03 — Boss Mode Crash/Animation Regression

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Home -> Boss | GameScreen mở, không crash UI |
| 2 | Quan sát HUD | Có title Boss stage, HP bar, PHASE 1, weak color, "×2" |
| 3 | Đợi shimmer HP bar 3 giây | HP bar shimmer không gây exception |
| 4 | Match màu không yếu | Boss mất HP thấp, HP bar animate đúng ratio |
| 5 | Match màu yếu | Damage cao hơn, weak color hint vẫn đúng |
| 6 | Boss retaliate sau interval | "BOSS STRIKE!" animate rồi biến mất |
| 7 | HP xuống phase 2/3 | Phase badge đổi màu/label, không layout shift mạnh |
| 8 | Kill boss | Win dialog hiện, không bị kẹt Flame/input |
| 9 | Hết lượt khi boss còn HP | Lose dialog hiện |
| 10 | Đọc logcat | Không có `FATAL EXCEPTION`, `E/flutter`, `RenderFlex overflowed` |

---

## TC-11-04 — Endless

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Home -> Endless | Stage 1, score HUD, board load |
| 2 | Tăng score qua ngưỡng | Stage tăng, event/hud cập nhật |
| 3 | Event gem rain/score x2 nếu gặp | Animation không che board, score tính đúng |
| 4 | Hết lượt | End panel hiện, high score lưu |

---

## TC-11-05 — Color Rush

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Home -> Color Rush | Hot color HUD hiện |
| 2 | Clear hot color | Bonus/streak tăng, feedback rõ |
| 3 | Clear màu khác | Streak reset |
| 4 | Sau mỗi N lượt | Hot color đổi, animation không giật |

---

## TC-11-06 — Gravity

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Home -> Gravity | HUD có hướng gravity |
| 2 | Chơi đến lượt flip | Board flip/column animation chạy |
| 3 | Sau flip | Gem settle theo hướng mới, input không stuck |
| 4 | Win/lose | Dialog đúng, không unlock campaign |

---

## TC-11-07 — Rhythm

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Home -> Rhythm | Beat dots/groove/BPM HUD hiện |
| 2 | Swap gần beat | PERFECT/GOOD animate, groove tăng |
| 3 | Swap lệch beat | LATE/MISS animate, groove giảm |
| 4 | Groove max | Màu HUD đổi, score bonus rõ |

---

## TC-11-08 — Soda

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Home -> Soda | Water/bottle HUD/overlay hiện |
| 2 | Clear gem | Fill tăng, nước dâng mượt |
| 3 | Nozzle pulse định kỳ | Pulse không che input |
| 4 | Đủ bottle target | Win dialog |

---

## TC-11-09 — Survival Tide

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Home -> Survival | Tide overlay bắt đầu thấp |
| 2 | Đợi không chơi | Nước dâng theo thời gian thực |
| 3 | Clear gem dưới nước | Tide bị đẩy lùi |
| 4 | Nước chạm đỉnh | Lose/end panel, high score lưu |

---

## TC-11-10 — Labyrinth

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Home -> Labyrinth | Layout có tường/fog |
| 2 | Match gần vùng thấy | Fog/hint không lộ sai vùng |
| 3 | Sau N lượt | Maze shift animation chạy, gem settle hợp lệ |
| 4 | Drop đủ crystal | Win dialog |

---

## TC-11-11 — Puzzle

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Home -> Puzzle | PuzzleSelectScreen hiện 8 puzzle |
| 2 | Chọn puzzle 1 | Board seed cố định |
| 3 | Clear gem | Không refill gem mới |
| 4 | Chơi lại puzzle 1 | Board ban đầu giống lần trước |
| 5 | Win puzzle | Sao lưu, puzzle tiếp theo unlock |

---

## TC-11-12 — Rush

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Home -> Rush | Timer 02:00, moves vô hạn không hiện 999 xấu |
| 2 | Match liên tục | Time bonus text hiện khi có bonus |
| 3 | Timer hết | End panel hiện, score/high score đúng |
| 4 | Tap Again | Restart vẫn là Rush, không rơi về campaign |

---

## TC-11-13 — Zen

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Home -> Zen | Không có win/lose target, lượt vô hạn |
| 2 | Chơi 20 nước | Không tự kết thúc |
| 3 | Bấm X | Confirm quit hiện |
| 4 | Xác nhận thoát | Zen high score lưu |

---

## TC-11-14 — Daily

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Home -> Daily | Board seed theo ngày, mutator áp đúng |
| 2 | Ghi lại objective/mutator | Chơi lại cùng ngày giống objective/mutator |
| 3 | Win lần đầu | Reward + streak daily |
| 4 | Win lại cùng ngày | Không farm reward lần 2 |

---

## TC-11-15 — Versus / Coop

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Home -> 2 Players | Select screen hiện Versus và Coop |
| 2 | Chọn Versus | Countdown 3-2-1, 2 board split |
| 3 | Player combo lớn | Junk gửi sang board đối thủ |
| 4 | Hết 60s | Winner/draw đúng |
| 5 | Chọn Coop | Điểm 2 người cộng chung, đạt goal thì coop win |

---

## TC-11-16 — Device Stress Pass

| # | Bước | Kết quả mong đợi |
|---|------|------------------|
| 1 | Chơi lần lượt 13 challenge entries, mỗi mode tối thiểu 90 giây | Không crash, không memory spike rõ |
| 2 | Mỗi mode bấm Home/Again 3 lần | Không rò state mode cũ |
| 3 | Chạy app background rồi foreground | Không vỡ animation/timer |
| 4 | Đọc logcat sau toàn bộ pass | Không có crash/assertion/ANR |

