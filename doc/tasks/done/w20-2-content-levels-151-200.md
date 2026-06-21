---
id: w20-2-content-levels-151-200
title: Nội dung mới — Thế giới 9-10 + màn 151-200
wave: 20
phase: 2
status: done
owner: claude
priority: high
---

# Phase 2 — Content: levels 151-200 + thế giới 9-10

## Bối cảnh
Game hiện có 150 màn / 8 thế giới (kết thúc ở "Neon Apex", W8 ngắn 141-150).
Wave 20.2 mở rộng lên 200 màn / 10 thế giới.

## Thiết kế thế giới mới

### Thế giới 9 — "Void Circuit" (màn 151-170)
- Accent màu: `Color(0xFF7B2FBE)` (violet đậm)
- Chủ đề: mạch điện trong không gian — weave Gravity Streams nhiều chiều + bố cục cầu
- Cơ chế weave mới: flow đa chiều (chữ Z, xoắn ốc), cage + bottleneck kết hợp
- Đặt 1-2 Super-Hard màn (cuối thế giới, số 170)

### Thế giới 10 — "Zenith Neon" (màn 171-200)
- Accent màu: `Color(0xFFFF4081)` (neon pink — finale)
- Chủ đề: đỉnh cao neon — tất cả cơ chế xuất hiện + harder variants
- Màn finale (200): Super-Hard, layout đặc biệt, không sawtooth-relief
- Story: chỉ hiện story beats nếu có thời gian (optional, bỏ nếu phức tạp)

## Triển khai

### levels.dart
- `kLevelCount = 200` (từ 150)
- Thêm `kWorlds` entry cho world 9, 10 (tên + màu + range)
- `accentForWorld(9/10)` — đã tự wrap, chỉ đảm bảo màu riêng
- Weave mới: thêm entries vào `kLayoutLevels`, `kFlowLevels`, `kCageLevels`,
  `kDeadZoneLevels`, `kBombLevels`, `kConveyorLevels`, `kPortalLevels`
  cho màn 151-200 (theo pattern chỉ số màn)
- Màn có layout cần thêm map string vào `kLayoutMaps` (hoặc tái dùng maps cũ)

### Cân bằng
- `_tierMul` / `_tierMoveDelta` / `_collectCapMul` đã có tiers — kiểm tra world 9-10
  có đường cong hợp lý (không đột ngột quá khó)
- `tool/playtest.dart`: mở rộng chạy 200 màn, verify 0 màn quá-khó

### i18n
- `world_name_9` / `world_name_10` (en + vi), 20 ngôn ngữ qua lớp merge mới `_w20ByLang`
- Coverage test ≥80% vẫn pass

### Test
- `w20_content_test.dart`: 200 màn / 10 thế giới, accent wrap, weave mới fill-winnable
- Cập nhật test cũ nếu hardcode 150/8

## Rủi ro
- **Layout mới**: mọi layout đều cần verify winnability (bài học W15 labyrinth bất khả thi)
- Đường cong W9-10 có thể quá khó cho Tier Normal — cần playtest validate
- `kLevelCount` thay đổi: cập nhật tất cả nơi dùng (story `kStoryWorlds` giữ 5)
