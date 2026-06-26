---
id: w22-3-onboarding
title: First-launch Onboarding — tour Home lần đầu
wave: 22
phase: 3
status: todo
owner: claude
---

# Phase 3 — First-launch Onboarding

## ⚠️ Tutorial gameplay ĐÃ CÓ — đây là bổ sung tour HOME

| Có sẵn | File:line |
|---|---|
| Tutorial "HOW TO PLAY" 3 bước trong game (L1-only) | `game_screen_controller.dart:34-95` (check `tutorialSeen==0` `:56`, set 1 `:94`) |
| Cờ `tutorialSeen` | `core/storage_service.dart:35` |
| Story intro overlay (Luma) | `data/story.dart:53` (`storyStartTriggerFor`), `story_controller.dart:24` (`maybeShow`), key `storySeen(beatId)` |
| NeonDialog.overlay pattern | `widgets/neon_dialog.dart:137-149`; ví dụ `widgets/story_overlay.dart:24` |

**Gap:** người mới mở app lần đầu KHÔNG được giới thiệu các khu trên Home (side-mode, shop,
leaderboard, battle pass…). Họ chỉ thấy 1 rừng icon. → Wave 22 thêm **tour Home 1 lần**.

## Thiết kế — Home Coach-marks (1 lần)

- Cờ mới `StorageKeys.homeTourSeen` (mirror `tutorialSeen`).
- Lần đầu mở Home (homeTourSeen==0): hiện chuỗi **coach-mark** 3-4 bước, mỗi bước highlight 1 khu
  + 1 dòng giải thích ngắn (NeonDialog.overlay + lỗ khoét spotlight quanh widget mục tiêu):
  1. "CHƠI NGAY" → chiến dịch 200 màn.
  2. Hàng THỬ THÁCH → các chế độ phụ (Vô tận, Trùm, Tốc chiến…).
  3. Hàng PHẦN THƯỞNG → Cửa hàng, Battle Pass, **Bảng xếp hạng** (mới).
  4. Nút mạng/xu (HUD trên) → kinh tế.
- Nút "Bỏ qua" + "Tiếp" mỗi bước; kết thúc/skip → set homeTourSeen=1.
- ⚠️ **Thứ tự với tutorial gameplay**: Home tour chạy TRƯỚC (ở Home), tutorial HOW TO PLAY chạy
  khi vào L1. Không trùng vì khác màn. Story intro (L1) chạy sau tutorial — chuỗi đã có.

## Triển khai
1. `StorageKeys.homeTourSeen` + thêm vào `resetProgress()`.
2. `HomeTourController` (hoặc state trong HomeScreen) — RxInt step, đọc cờ ở post-frame onInit
   (xem [[getx-oninit-postframe]] để tránh mutate Rx during build).
3. Widget coach-mark overlay (spotlight: Stack + ColorFiltered/CustomPainter khoét lỗ quanh
   target rect). Lấy rect bằng GlobalKey trên các khu Home.
4. i18n keys `tour_play/tour_modes/tour_rewards/tour_economy/...` vào `_extraEn`+`_extraVi`.
5. Test: cờ chưa xem → tour hiện; sau skip → set 1; mở lại không hiện. `flutter analyze` 0.

## Acceptance criteria
- [ ] Lần đầu mở Home: tour hiện; skip/hoàn tất → set `homeTourSeen=1`.
- [ ] Mở Home lần sau: KHÔNG hiện lại.
- [ ] `resetProgress()` xoá `homeTourSeen` → tour hiện lại sau reset (đúng "fresh").
- [ ] Không chặn input vĩnh viễn nếu lỗi (luôn có nút Bỏ qua).
- [ ] Không đụng/sai thứ tự với tutorial L1 + story intro.
- [ ] `flutter analyze` 0 issue; widget test mount Home có/không tour theo cờ.

## Lưu ý
- Spotlight coach-mark đụng layout Home (cần GlobalKey rect) — rủi ro TB, test kỹ trên nhiều cỡ màn.
- Liên quan: [[home-fullwidth-no-fittedbox]], [[reset-permanent-controllers]], [[getx-oninit-postframe]].
