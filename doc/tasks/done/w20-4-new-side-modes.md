---
id: w20-4-new-side-modes
title: Chế độ phụ mới (Wave 20.4 — xác nhận sau khi W20.1-3 xong)
wave: 20
phase: 4
status: done
owner: claude
priority: low
---

# Phase 4 — Side mode mới (placeholder, chi tiết sau)

## Bối cảnh
Sau khi hoàn thành W20.1 (audit) + W20.2 (content) + W20.3 (meta), nếu còn thời gian
và energy, thêm 1-2 chế độ phụ hoàn toàn mới.

## Ứng viên (cần chọn khi tới W20.4)

### Option A — Time Bomb Blitz (chaos mode)
Bàn có nhiều bom (≥4) đồng thời với đồng hồ ngắn (15s/lượt). Mỗi swap thanh
công (defuse) 1 bom. Vui, nhanh, adrenaline. Tái dùng bomb engine (W10).

### Option B — Mirror Match (co-op 1 máy)
Hai bàn mirror nhau (cùng seed, cùng mirror). Người chơi thực hiện N lượt trên bàn
trái; bàn phải tự động "echo" nước đi đối xứng. Mục tiêu: đồng bộ clear jelly cả 2 bàn.
Cơ chế độc đáo, tái dùng Versus rendering.

### Option C — Cascade Challenge (depth mode)
Chỉ tính điểm khi cascade ≥ 3 tầng. Match đơn không cho điểm. Người chơi phải tư duy
sâu về chain reaction. Mục tiêu: đạt N cascade trong giới hạn lượt.

### Option D — Zen Mode (không thua)
Không có điều kiện thua — chơi bao lâu tùy thích. Không mạng, không lượt giới hạn.
Chỉ có điểm tích lũy và high score. Thư giãn. Đơn giản để implement.

## Nguyên tắc chung
- Mọi mode mới phải vào `isSideMode` (isolation)
- Phải có winnability test (hoặc "no-lose-condition" rõ ràng)
- Phải có unit + widget test
- i18n en+vi đầy đủ, 20 ngôn ngữ fallback

## Quyết định
**Hoãn tới khi xong W20.1-W20.3.** Sẽ AskUserQuestion khi tới bước này để chọn 1-2 option.
