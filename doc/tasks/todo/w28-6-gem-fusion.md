---
id: w28-6-gem-fusion
title: "Gem Fusion/Crafting"
wave: 28
phase: 6
status: todo
owner: claude
---

# Phase 6 — Gem Fusion/Crafting

## Concept

Ghép 2 gem đặc biệt cùng loại (2 striped → 1 bomb, 2 bomb → 1 rainbow...) bằng
thao tác chủ động của người chơi, ngoài việc match tự nhiên tạo ra special gem.
Thêm 1 lớp chiến thuật input hoàn toàn mới — khác cơ chế "match để tạo" hiện tại.

## Phạm vi đề xuất

1. Input mechanic mới: tap gem đặc biệt thứ 1 → tap gem đặc biệt thứ 2 cùng loại
   (không cần liền kề) → fusion animation → tạo gem cấp cao hơn tại vị trí gem 2.
2. Bảng công thức fusion rõ ràng (2 striped cùng hướng → bomb; 2 bomb → rainbow;
   không fusion lightBall/diagonal ở bản đầu — giữ scope nhỏ).
3. Chỉ bật ở mode cho phép thong thả (Campaign/Zen/Endless) — **không** bật ở mode
   giới hạn giờ chặt (Rush/Rhythm) để tránh phá nhịp gameplay đã tuned.

## Rủi ro cần lưu ý

- Input mechanic mới đụng trực tiếp `neon_jewel_game.dart` (core swap/tap
  gesture) — rủi ro cao nhất trong các idea Wave 28, cần thiết kế kỹ tránh xung
  đột với gesture swap hiện có (double-tap vs swap 2 gem liền kề).
- Cần playtest lại độ khó — fusion có thể làm dễ hơn dự tính nếu tạo rainbow quá
  nhanh; xem xét giới hạn số lần fusion/màn nếu cần.

## Việc cần làm khi bắt đầu

- [ ] Đọc kỹ gesture detector hiện có (`PanGestureRecognizer`/`TapDetector`) trước
      khi thêm input mode mới, tránh xung đột với swap.
- [ ] Thiết kế bảng công thức fusion, review cân bằng trước khi code.
- [ ] `dart run tool/playtest.dart` re-validate các level cho phép fusion.
- [ ] Verify máy thật: fusion animation không giật, không double-trigger swap.
