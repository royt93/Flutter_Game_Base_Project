# I17 — Tile material variants

**Epic:** Neon/Glow · **SP:** 8 · **Pri:** Could · **Deps:** I14 (cùng khái niệm world identity)

## Mục tiêu
`BlockComponent` đổi chất liệu render theo world: jelly (world đầu, mềm bóng),
crystal (world giữa, góc cạnh phản chiếu), metal (world cuối, ánh kim).

## Vì sao
Tile trông giống hệt suốt 200 màn dù world đổi màu nền (I14) — material khác
biệt tăng cảm giác tiến trình rõ hơn chỉ đổi màu.

## Acceptance criteria
- [ ] `BlockComponent` nhận variant (jelly/crystal/metal) theo `worldForLevel`
      hiện tại.
- [ ] Mỗi variant khác nhau ở highlight/shadow/border style — không đổi
      hitbox/gameplay.
- [ ] Không tăng chi phí render đáng kể (không thêm > 1 draw call/ô).
- [ ] Golden test: 3 variant render khác nhau rõ, cùng màu vẫn phân biệt được world.

## Subtasks (gợi ý file)
1. `lib/game/block_component.dart`: tham số variant + 3 style paint.
2. `lib/game/pop_star_game.dart`: truyền variant theo world khi build block.

## Ghi chú kỹ thuật
Chỉ đổi cách vẽ (paint/shader nhẹ), không đổi `colorGrid`/logic pop.

DoD chung: `../README.md`.
