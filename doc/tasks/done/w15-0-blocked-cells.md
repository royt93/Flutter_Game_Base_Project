---
id: w15-0-blocked-cells
title: Nền tảng ô đặc biệt + lỗ-cắt-cột (bố cục đa dạng)
wave: 15
phase: 0
status: done
owner: claude
---

# Phase 0 — Blocked cells / hole / no-drop + gravity lỗ-cắt-cột

Nền tảng cho "bố cục bàn đa dạng" kiểu Candy Crush. Bàn không còn buộc chữ nhật
8×8 đặc: có **ô tường (wall/blocked)** không chứa gem, tạo hình thoi/đồng hồ
cát/chữ thập/lỗ giữa…

## Thiết kế
- `enum CellKind { play, wall, noDrop }` — `wall` = ô không gem (blocked), `noDrop`
  = ô có gem nhưng KHÔNG bị trọng lực kéo (đảo nổi, dùng ở Phase 3).
- Level khai báo bố cục bằng **bản đồ ký tự** (vd `'#'`=wall, `'.'`=play) → parse
  thành `List<List<CellKind>>`. Thêm field `layout` (nullable) vào `LevelConfig`;
  null = bàn đặc như cũ (không hồi quy 100 màn hiện tại).
- Engine: lưới `blocked`/`noDrop`. `BoardFrame` skip ô wall (không vẽ slot) +
  `BlockedLayer` render khối đá neon ở ô wall.

## Gravity lỗ-cắt-cột (MVP)
- `_applyGravityAndRefill`: mỗi cột xử lý theo **đoạn liền mạch** giữa các wall
  (gem chỉ dồn trong đoạn của nó, refill từ đỉnh đoạn). Wall chặn không cho gem
  xuyên qua. (Trượt-chéo để Phase 1.)
- `_fillInitialBoard` skip ô wall. `_matchColorAt` trả null nếu wall.
- `_findMove`/`_doShuffle`/select/tap đều bỏ qua ô wall.

## Test (winnability)
- Parse bản đồ ký tự đúng; bàn có wall vẫn tìm được nước đi; gravity không sinh
  gem vào ô wall; đoạn cột bị cắt refill đúng; không hồi quy bàn đặc (null layout).
