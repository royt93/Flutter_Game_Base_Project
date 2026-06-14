---
id: w6-story-episode
title: Story / Episode + nhân vật NPC
wave: 6
status: done
owner: claude
---

# Story / Episode + nhân vật NPC

Thêm chiều sâu hành trình kiểu Candy Crush: mỗi thế giới có 1 vệ thần neon
(NPC) chào đón, cổ vũ giữa chặng và tiễn sang cõi kế tiếp.

## Đã làm
- **Data thuần** `lib/data/story.dart`: 15 beat (5 thế giới × intro/mid/outro),
  mỗi beat 2 dòng thoại. Helper `storyBeatFor`, `storyStartTriggerFor`.
- **NPC avatar** `lib/presentation/widgets/npc_avatar.dart`: 5 vệ thần vẽ bằng
  `CustomPainter` (tia sáng / nhịp tim / mạch điện / sao chổi / trăng khuyết),
  tô theo màu chủ đạo thế giới. Không cần asset.
- **StoryController** (GetX): `maybeShow(trigger, world, onComplete)` chỉ mở 1
  lần mỗi beat (cờ `StorageKeys.storySeen`), `next/prev/skip`.
- **StoryOverlay** dùng chung (overlay trong cây — route dialog no-op
  full-screen): avatar + tên NPC + thoại + chấm tiến trình + vuốt chuyển dòng.
- **Trigger**: intro/mid khi bắt đầu màn (World Map + Level Select, trước
  pre-game); outro sau khi thắng màn cuối thế giới (`proceedNextOrHome`).
- **i18n đủ 22 ngôn ngữ** (npc_name, story_*_title/l1/l2, story_next/skip/done).
  NPC names dùng fallback Latin (transliterate tự nhiên cho script ngoài Latin).
- **Guide**: thêm section "Cốt truyện".
- `resetProgress` xoá cờ story đã xem.

## Kết quả
0 analyzer issue · test mới ở `test/w6_test.dart` (story beats + controller).
