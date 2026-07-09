---
id: w28-7-neon-companion
title: "Neon Companion (Pet cosmetic)"
wave: 28
phase: 7
status: todo
owner: claude
---

# Phase 7 — Neon Companion (Pet)

## Concept

Lớp thu thập cosmetic mới, khác Collection sticker hiện có — vật nuôi (pet) hiển
thị cạnh HUD trong lúc chơi, có thể tặng hiệu ứng nhỏ (glow/particle) khi active.
Không đụng economy Collection cũ đã cân bằng — thêm lớp thu thập riêng cho người
muốn sưu tập thêm.

## Phạm vi đề xuất

1. `PetController` mới (permanent, theo pattern các controller hiện có) — quản lý
   danh sách pet sở hữu + pet đang active.
2. Nguồn unlock: tái dùng progress đã có (stars/coins đã tích luỹ) làm điều kiện
   mở, **không** tạo currency mới để tránh phình economy.
3. Hiệu ứng active: cosmetic thuần (đọc qua `ActiveCosmetics` pattern có sẵn,
   giống `gemSkin`), không ảnh hưởng gameplay số liệu.
4. Cần asset mới (art pet) — **không phải chỉ code**, cần nguồn asset trước khi
   bắt tay code (placeholder shape nếu chưa có art).

## Rủi ro cần lưu ý

- Cần asset pipeline (art pet) — nếu chưa có nguồn art, có thể tạm dùng shape
  procedural (giống gem shape hiện tại) làm placeholder, không chặn theo asset.
- Nhớ wire `resetState()` vào `resetProgress()` nếu `PetController` có persisted
  state (theo Reward Anti-Exploit pattern trong `CLAUDE.md`).

## Việc cần làm khi bắt đầu

- [ ] Xác nhận nguồn asset pet trước khi thiết kế UI cụ thể.
- [ ] Đọc pattern `ActiveCosmetics` (`lib/data/cosmetics.dart`) trước khi thêm field mới.
- [ ] Test `resetProgress()` xoá sạch state Pet (disk + RAM).
- [ ] Verify máy thật: pet hiện đúng cạnh HUD, không che gameplay quan trọng.
