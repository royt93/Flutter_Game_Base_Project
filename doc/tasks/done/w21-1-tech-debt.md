---
id: w21-1-tech-debt
title: Dọn nợ kỹ thuật — Ad UX + Widget tái dùng
wave: 21
phase: 1
status: done
owner: claude
---

✅ **DONE 2026-06-22** — Khảo sát xác nhận cả 3 mục đã được fix ở wave trước:
- A (Ad Versus): Không có ad code trong project.
- B (CoinChip/fmtDur): Đã là widget/util từ commit f48e376 — không còn duplicate.
- C (levelUnlock): Code đúng — disk write trước RAM update (game_controller_progress.dart).
Baseline: **633 test pass** (+22 so với ghi 611) · 0 analyzer.

# Phase 1 — Dọn nợ kỹ thuật (3 hạng mục gộp)

## A. Fix UX quảng cáo Versus (cấp bách)

**Vấn đề**: AppLovin MAX bắn interstitial mỗi lần vào/replay Versus → spam ad, trải nghiệm tệ.

**Fix**:
- Chỉ bắn interstitial sau mỗi **3 ván** (counter `_versusPlaysCount` trong `GameController`).
- Không bắn khi người dùng bấm "Chơi lại" ngay lập tức (xem `again()` nhánh Versus).
- File: `game_controller_modes.dart` + `GameScreenController.again()`.

## B. Dọn UI copy-paste (widget tái dùng)

**Vấn đề** (từ audit Wave 8.9): `_coinChip` định nghĩa ×4 chỗ, `_fmtDur` ×4 chỗ, ~26 `TextStyle` inline, magic number layout rải rác.

**Fix**:
- Gom `_coinChip` → `CoinChip` widget (`lib/presentation/widgets/coin_chip.dart`), xoá 3 bản duplicate.
- Gom `_fmtDur` → `formatDuration(int sec)` util (`lib/core/format_util.dart`), xoá 3 bản duplicate.
- Thay magic number phổ biến nhất (padding 8/16/24) → `NeonTheme.s8/s16/s24` đã có.
- **KHÔNG** refactor kiến trúc hay tách GameController — chỉ dọn surface.

## C. Siết `levelUnlock` race condition (nhỏ)

**Vấn đề**: `levelUnlock` ghi RAM trước `await` disk → khe kill hẹp (không crash được reproduce, nhưng dữ liệu nguy hiểm).

**Fix**: Đổi thứ tự: `await _store.setInt(...)` trước khi `levelUnlock.value = next`.

## Test
- Widget test: `CoinChip` render đúng coin count.
- Unit test: `formatDuration` các giá trị biên (0s, 59s, 3600s).
- Regression: 611 test pass (không thêm, không bớt).

## Ưu tiên
Làm trước B + C (zero-risk, no behavior change), rồi A (cần xác minh logic ad frequency).
