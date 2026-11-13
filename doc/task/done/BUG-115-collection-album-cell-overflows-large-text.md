---
id: BUG-115
title: "CollectionAlbumPanel: ô lưới tràn dọc 20-22px ở 320dp với chữ 2.0x"
type: bug
layer: lib/widgets/common
priority: P2
effort: S
source: "FEAT-200 pha 2d: viewport sweep 2026-11-13"
---

## Tái hiện (sweep)
`collection_album_panel.dart` `_CollectionCell` (Column icon 30 + tên + đếm) trong lưới 3 cột `childAspectRatio: 0.78` (ô có tỉ lệ cố định). Ở 320x480 với text scale 2.0: `A RenderFlex overflowed by 20/22 pixels on the bottom`. Vị trí lấy bằng test tạm bắt `FlutterErrorDetails`. Các viewport khác và chữ 1.0x đạt.

## Đã sửa
Bọc Column trong `FittedBox(scaleDown)` + `mainAxisSize.min`: co khi không vừa, giữ nguyên khi vừa. Golden `collection_album_panel` và test riêng vẫn xanh (không đổi pixel ở kích thước chuẩn). Sweep pha 2d: 11 widget panel/list (QuestBoardPanel, RewardChoicePanel, ProfileStatsCard, CheckpointResumeCard, EventCalendarCard, GiftLivesRequestCard, TeamRosterList, CollectionAlbumPanel, BackupRestorePanel, ReminderPreferencesPanel, ConsentPreferencesPanel), 68 test xanh. Tổng 39 widget được sweep, 4 lỗi thật bắt được qua các pha (BUG-107, 114 x3, 115).
