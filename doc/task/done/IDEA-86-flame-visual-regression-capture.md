---
id: IDEA-86
title: "Flame visual regression capture"
type: idea
layer: testing/visual
priority: P3
effort: M
status: speculative
---

## Giả thuyết

Các thay đổi camera, sprite frame hoặc game HUD có thể gây render regression khó phát hiện qua state assertions.

## Ý tưởng

Khảo sát deterministic frame capture/golden workflow cho Flame với fixed viewport, seed, time step và assets; tuân thủ repo rule: golden baseline chỉ qua Linux workflow.

## Discovery gate

- [ ] Xác nhận visual regression chưa được test bằng state/geometry assertions.
- [ ] Prototype render stability trên CI host và ghi giới hạn font/GPU/backend.
- [ ] Xác định capture timing deterministic; không dùng `pumpAndSettle` cho game loop ticker.
- [ ] Chọn golden hay image-diff threshold dựa trên độ ổn định đo được.

## Prompt loop feature

Đọc `roy_game_test.dart`, golden workflow và CI guidance trong CLAUDE.md. Không generate golden từ macOS; chỉ dùng Linux workflow đã quy định. Thử repeated captures trước khi thêm test để đo flakiness. Nếu duyệt, test seed/viewport/time deterministic, golden update policy và diff evidence. Device smoke chỉ nếu cần kiểm tra device rendering claim. Audit/score /10; commit/push chỉ sau approval và CI xanh.

## Kết quả discovery (2026-10-24)

- Repo có golden matrix support và widget goldens; golden refresh bắt buộc qua `.github/workflows/regenerate-goldens.yml` trên Linux, không tạo baseline bằng local macOS.
- `RoyGame` là game-loop/ticker runtime với moving `BouncingOrb`, tap/collision, pooled particles; `test/presentation/game/roy_game_test.dart` dùng bounded pumping, không `pumpAndSettle`.
- Chưa thấy Flame game-frame golden/capture test hoặc approved sprite asset. Không có current golden failure/visual regression report làm căn cứ ưu tiên.
- Flame output capture có thể phụ thuộc backend/host; trước khi thêm gate cần repeated-run stability proof và xác định deterministic time/seed/viewport/assets.

## Kết luận

Không có regression/use case để justify harness. Đóng no-go; mở lại khi có visual regression cụ thể hoặc consumer request. Không thay đổi existing golden workflow.

## Quyết định

Người dùng duyệt đóng no-go. Chưa có regression/use case/asset fixture để justify harness; mở lại khi có request cụ thể. Chưa code hoặc tạo golden.
