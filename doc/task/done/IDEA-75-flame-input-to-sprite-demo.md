---
id: IDEA-75
title: "Flame input-to-sprite end-to-end demo"
type: idea
layer: example/game
priority: P2
effort: M
status: speculative
---

## Giả thuyết

Consumer mới có thể học nhanh hơn từ demo sprite có tap/drag input, animation, pause/resume và asset loading thay vì chỉ Flame shell/component ví dụ.

## Nền tảng

`RoyGame` minh họa Flame integration; package có lifecycle coordinator, asset preload và seeded random services.

## Ý tưởng

Example-only demo; không thêm package API trừ khi use case chứng minh gap reusable.

## Discovery gate

- [ ] Xác nhận demo gap từ consumer onboarding/feedback.
- [ ] Chọn input pattern và sprite asset/license; xác định supported platform.
- [ ] Giữ caller-owned game state, keyboard/mouse/touch accessibility expectations rõ.
- [ ] Không trùng phần đã có trong `RoyGame` hoặc showcase.

## Prompt loop feature

Đọc `RoyGame`, `GameDemoScreen`, integration boot tests, asset preload và lifecycle coordinator. Bảo đảm demo không giả làm backend gameplay. Nếu duyệt feature, thêm deterministic Flame tests cho input/state, bounded pumping, pause/resume/dispose; device smoke cho touch flow. End loop audit/score /10 và đầy đủ test/evidence phù hợp. Không commit/push nếu chưa có user approval và CI xanh; score không tự cấp phép push.

## Quyết định

Người dùng duyệt đóng no-go. Chưa có onboarding request hay licensed sprite fixture; showcase hiện giả lập asset loading. Mở lại khi có consumer gap và asset phù hợp.
