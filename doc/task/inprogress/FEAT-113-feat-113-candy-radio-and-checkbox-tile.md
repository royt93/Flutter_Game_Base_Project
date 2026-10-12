---
id: FEAT-113
title: CandyRadioGroup & CandyCheckboxTile — Lựa chọn radio và hộp kiểm bo nảy
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Thư viện hiện chỉ có ToggleSwitch, thiếu hoàn toàn Radio button và Checkbox cho các form cài đặt, chọn chế độ chơi, danh sách tuỳ chọn app.

## Đề xuất phạm vi
Cung cấp CandyRadioGroup<T> và CandyCheckboxTile phong cách kẹo bo tròn, viền đậm, dấu tích/chấm tròn nảy đàn hồi (scale bounce) khi được chọn.

## Kiểm thử
- [x] **Unit/widget test**: Generic radio emits selected value; checkbox toggles bool; selection/checked semantics; Reduced Motion; empty/duplicate options validation.
- [x] **Showcase test**: Radio + checkbox caller state updates, bounce marker without layout shift.
- [x] **S24 Ultra smoke**: Radio and checkbox choices tapped on SM-S928B; caller state updated. No simulator used.
- [x] **Host validation**: root 2950/example 243 suites, analyzers and quality gates pass.

## Hiệu năng & Animation
- [x] `AnimatedScale`/container animation uses zero duration for Reduced Motion; Semantics exposes selected/checked, fixed marker space avoids layout shift.
- [ ] 60 FPS benchmark not measured.
