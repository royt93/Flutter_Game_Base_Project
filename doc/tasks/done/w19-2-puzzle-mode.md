---
id: w19-2-puzzle-mode
title: Chế độ Cấu đố (Puzzle) — lời giải cố định
wave: 19
phase: 2
status: todo
owner: claude
---

# Phase 2 — Chế độ phụ mới: Cấu đố (Puzzle Mode)

## Bối cảnh
Tất cả 9 chế độ phụ hiện tại đều có **lưới ngẫu nhiên** và **nhiều nước đi đúng**. Chưa
có chế độ nào đòi hỏi **tư duy thuần logic** với lời giải duy nhất. Puzzle Mode lấp khoảng
trống này — khác biệt thật (🟢 A) mà không cần engine mới.

## Thiết kế — Cấu đố (Puzzle)

### Cơ chế cốt lõi
- Bàn **cố định** (không refill gem sau khi nổ — hoặc refill có kiểm soát).
- Mục tiêu: dọn sạch một vùng **obstacle / jelly cụ thể** trong đúng **N lượt** (không
  hơn, không kém).
- Lệch N lượt → thất bại. Đây là ràng buộc "exact-move" — khác hẳn campaign.
- Không tốn mạng; thất bại → thử lại ngay.

### Nội dung
- Bộ puzzle cứng bao gồm 20 cấu đố thiết kế tay (hand-crafted), tăng dần độ phức tạp.
- Cấu đố lưu trong `lib/data/puzzles.dart` (list `PuzzleDef`: layout, seed, N-moves, goal).
- Mở khoá tuần tự (sau khi giải puzzle trước).

### Phân biệt với Campaign
| | Campaign | Puzzle |
|---|---|---|
| Lưới | Random seed | Cố định, hand-crafted |
| Gem refill | Có | Không (hoặc hạn chế) |
| Mục tiêu | Đạt ngưỡng | Clear đúng vùng |
| Số lượt | "Dùng nhiều nhất" | "Dùng đúng N" |
| Thất bại | Hết lượt | Lệch lượt hoặc không đạt mục tiêu |

### Phần thưởng
- Giải puzzle → sao (1-3 theo lượt dư nếu có) + xu nhỏ.
- Hoàn thành tất cả 20 → badge "Nhà chiến lược" (cosmetic).

## Triển khai
- `lib/data/puzzles.dart`: `PuzzleDef` list (20 cấu đố).
- `GameController.startPuzzle(puzzleDef)`: mode riêng `isPuzzle`, refill = off (hoặc
  controlled), exact-N constraint ở `checkEnd`.
- UI: card "CẤU ĐỐ" trong khu Thử thách + màn chọn puzzle (grid nhỏ 20 ô, trạng thái
  giải/chưa).
- i18n: `puzzle_*` key.

## Test
- Puzzle load đúng layout/seed/N.
- Exact-move constraint kích đúng (N lượt = thua nếu chưa xong; 0 lượt thừa = win).
- Không tốn mạng; `isPuzzle` cô lập tiến trình campaign.
- Hoàn thành → badge 1 lần.

## Lưu ý
- **Tốn thời gian thiết kế nội dung** (20 puzzle hand-crafted) — đây là rủi ro chính.
  Có thể làm trước 5-10 puzzle để test cơ chế, mở rộng sau.
- Cơ chế engine không phức tạp (tái dùng obstacle/jelly + tắt refill) — phần khó là
  **cân bằng puzzle** (không quá dễ/khó, luôn có lời giải trong N lượt).
- Liên quan: [[side-mode-isolation]], [[w14-obstacle-licorice-jam]], [[w15-layout-architecture]].
