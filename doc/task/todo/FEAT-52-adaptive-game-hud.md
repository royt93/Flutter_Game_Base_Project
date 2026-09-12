---
id: FEAT-52
title: "AdaptiveGameHud — HUD an toàn cho notch, tablet, landscape và Flame viewport"
type: feature
layer: presentation/widget
priority: P1
effort: L
depends_on: [ENH-37, ENH-38, ENH-40, ENH-56]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn đặt top/bottom/side HUD bằng slot mà không tự xử lý từng loại màn hình.

## Sprint slices
- Slot topStart/topCenter/topEnd/bottom/side/overlay và constraint model.
- SafeArea/display features/orientation/text-scale/RTL.
- Optional Flame viewport bounds để HUD không che playfield.
- Compact/expanded breakpoints inject được và debug bounds.

## Acceptance criteria
- [ ] Không overlap system inset/cutout trên fixture thiết bị đại diện.
- [ ] Slot co/ẩn/chuyển layout deterministic ở portrait/landscape/tablet.
- [ ] Text scale/RTL/keyboard inset không overflow các case chuẩn.
- [ ] Không rebuild toàn HUD khi chỉ một reactive slot đổi nếu tránh được.

## Prompt loop feature
Đọc task và widget conventions; tạo layout matrix/golden fixtures rồi TDD. End loop: audit, chấm /10; unit test + widget test + integration test mọi size/orientation/inset/RTL; analyze/test root + example; smoke trên Android device thật cả portrait/landscape có screenshot. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

