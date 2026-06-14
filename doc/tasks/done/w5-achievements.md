---
id: w5-achievements
title: Achievement / Thành tựu
wave: 5
group: Meta giữ chân
status: todo
owner: claude
---

## Mục tiêu
Hệ thống thành tựu offline: mốc tiến trình → thưởng xu khi nhận.

## Phạm vi
- Model `Achievement` (id, icon, ngưỡng, loại) + danh sách định nghĩa (`lib/data/achievements.dart`).
- Loại mốc: tổng sao, số màn thắng, combo cao nhất, win streak, tổng xu kiếm, số special tạo ra.
- `AchievementController` (GetX): theo dõi tiến trình qua StorageService, phát hiện mở khoá, cho nhận thưởng xu.
- Màn `AchievementsScreen` (NeonAppBar + NeonBg + lưới thẻ, thanh tiến trình, nút NHẬN khi đạt).
- Entry từ Home (nút mới) + badge khi có thành tựu chưa nhận.
- i18n key (`_extraEn` + `_extraVi`).

## Acceptance
- 0 analyzer issue; unit test cho controller (mở khoá đúng ngưỡng, nhận thưởng 1 lần).
- Build APK debug OK.
</content>
</invoke>
