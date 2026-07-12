# Tasks — Pop Star Blast (per-file backlog)

Mỗi file = 1 task junior cầm làm được. DoD/quy ước chung: `../README.md`.
Tất cả 24 task F/A/G + 7 task Ideas/Polish (I/T) dưới đây đã được user chốt.
Ý tưởng còn lại chưa chốt: `IDEAS.md`.

## Nhóm & mã task

### Features (F)
| ID | Task | SP | Pri |
|----|------|----|----|
| [F1](F1-combo-multiplier.md) | Combo/chain multiplier | 5 | Must |
| [F2](F2-daily-reward.md) | Daily reward + streak | 5 | Should |
| [F3](F3-color-rainbow-bomb.md) | Booster color/rainbow bomb | 5 | Should |
| [F4](F4-level-path-map.md) | Level path map + world theme | 8 | Should |
| [F5](F5-power-tiles.md) | Power tiles / super gems | 13 | Could |
| [F6](F6-obstacle-objectives.md) | Obstacle tiles + objective đa dạng | 13 | Could |
| [F7](F7-star-road-chest.md) | Star road + chest reward | 8 | Should |
| [F8](F8-modes-timeattack-zen.md) | Mode Time-attack + Zen | 8 | Could |

### Animation (A)
| ID | Task | SP | Pri |
|----|------|----|----|
| [A1](A1-juice-gameplay.md) | Juice: score popup + shake + squash | 5 | Must |
| [A2](A2-score-countup-progressbar.md) | Score count-up + progress bar target | 3 | Must |
| [A3](A3-route-button-motion.md) | Route transition + button bounce | 3 | Should |
| [A4](A4-mascot-reactions.md) | Mascot reaction động | 5 | Should |
| [A5](A5-win-choreography.md) | Win choreography dàn cảnh | 5 | Should |
| [A6](A6-board-intro-assemble.md) | Board intro assemble | 3 | Could |
| [A7](A7-slowmo-camera-punch.md) | Slow-mo + camera zoom-punch | 5 | Could |
| [A8](A8-ripple-anticipation.md) | Ripple chạm + anticipation squash | 3 | Could |

### Neon/Glow (G)
| ID | Task | SP | Pri |
|----|------|----|----|
| [G1](G1-group-glow-pulse.md) | Glow pulse nhóm + điểm dự kiến | 5 | Must |
| [G2](G2-pop-trail-flash.md) | Trail sáng + flash combo | 3 | Should |
| [G3](G3-hud-button-bloom.md) | Bloom/rim động nút + HUD | 3 | Could |
| [G4](G4-bg-reactive-glow.md) | Nền reactive glow theo combo | 5 | Could |
| [G5](G5-shader-bloom-aura.md) | Shader bloom aura (neon_glow.frag) | 8 | Should |
| [G6](G6-combo-heat.md) | Combo heat — bàn nóng sáng dần | 5 | Could |
| [G7](G7-neon-edge-trace.md) | Neon edge-trace nhóm chọn | 5 | Could |
| [G8](G8-glow-burst-shimmer.md) | Glow burst ring + idle shimmer | 5 | Could |

### Ideas & Polish (I/T)
| ID | Task | SP | Pri |
|----|------|----|----|
| [I11](I11-haptic-feedback.md) | Haptic feedback theo cỡ nhóm nổ | 2 | P1 |
| [T1](T1-settings-locale-test.md) | Fix settings_screen locale-change test | 3 | P2 |
| [I5](I5-free-undo.md) | Undo miễn phí 1 lần/màn | 2 | P1 |
| [I18](I18-colorblind-symbols.md) | Colorblind neon symbols | 5 | P2 |
| [I4](I4-predictive-hint.md) | Predictive hint (gợi ý nhóm to nhất) | 3 | P2 |
| [I13](I13-pop-sfx-pitch.md) | SFX pop cao độ theo cỡ nhóm (wire playMelodic) | 2 | P1 |
| [I2](I2-chain-tiles.md) | Color-lock / chain tiles | 5 | P2 |

## Thứ tự build đề xuất (tối ưu phụ thuộc + giá trị/công)

**Wave 1 — nền tảng cảm giác (fun/công thấp):** G1 → A1 → A2 → F1.
> Combo (F1) ăn theo glow-pulse (G1) + juice (A1) + count-up (A2). Làm cụm này
> trước cho "đã tay" tức thì, rẻ, rủi ro thấp.

**Wave 2 — celebration & motion:** A5 → A4 → A3 → G2.

**Wave 3 — meta & depth:** F7 → F3 → F2 → F8.

**Wave 4 — glow cao cấp:** G5 (shader) → G3 → G6 → G4 → G7 → G8.

**Wave 5 — nội dung lớn:** F5 (power tiles) → F6 (obstacle/objective) → F4 (path map).
> 3 task nặng nhất, đụng data/level design — làm sau khi core juice ổn.

Phụ thuộc chính: F1 chặn G1(điểm dự kiến hiển thị)/A1(popup combo)/G6(heat theo combo).
F5/F6 đụng `pop_star_game` + `levels.dart` → làm tuần tự, tránh song song xung đột.

**Wave 6 — Ideas & Polish (nhẹ trước, nặng sau):** I11 → I13 → I5 → T1 → I4 → I18 → I2.
> I11/I13/I5 độc lập, nhẹ, làm song song/tuần tự tuỳ ý. I2 (chain tiles) đụng cả
> `lib/logic/` lẫn `pop_star_game.dart` (gravity/collapse 2 grid song song) — nặng
> nhất nhóm này, nên plan riêng và làm cuối cùng.
