# Round 9 — Audit toàn source & backlog mới (2026-08-11)

Nguồn: đọc toàn bộ `lib/` (129 file Dart, 57.5k dòng) + đối chiếu 2 AI agent
độc lập (`codex exec`, `claude -p`). Mỗi task có file riêng trong `tasks/`.
DoD/DoR chung: [`README.md`](README.md). Quy ước SP/Pri/trạng thái: như cũ.

> **Quyết định phạm vi (chốt với PO 2026-08-11):** đợt này làm **kết hợp
> hardening + retention + content**, **KHÔNG** đưa quảng cáo (rewarded ads)
> hay IAP vào backlog — game giữ hướng miễn phí/không monetization. Mọi cơ
> chế "second chance"/"nhận thêm lượt" phải trả bằng coin/booster đã có
> trong game, không bằng xem quảng cáo.

## Tình trạng nền lúc audit

| Chỉ số | Giá trị |
|---|---|
| `flutter analyze` | ✅ 0 issue |
| `flutter test --exclude-tags slow` | ❌ **ĐỎ** — 1 failure (xem [[X16]]) |
| File Dart trong `lib/` | 129 (33.2k dòng là `app_translations.dart`) |
| File test | 118 |
| Task cũ trong `tasks/` | 117 (cao nhất I69 / X15 / T1) |
| Dependency runtime | 15, không có ads/IAP |
| TODO/FIXME trong source | 0 (10 comment `ponytail:` là ghi chú chủ ý) |

Chất lượng code nền **cao**: comment cite task ID, `_load()` re-validate id
từ const table, mọi nội dung "chung cho mọi người chơi" đều seed theo
epoch-day. Các phát hiện dưới đây là lỗ hổng thật ở rìa, không phải nợ kiến
trúc diện rộng.

---

## E6 — Hardening: đúng đắn, chống gian lận, hiệu năng (Must)

Bug thật, verify được từ code, có kịch bản tái hiện. **Làm trước mọi thứ
khác** — 3 trong số này làm hỏng dữ liệu người chơi hoặc chặn boot.

| ID | Tên | SP | Pri | Mức |
|----|-----|----|----|-----|
| [X16](tasks/X16-release-checklist-sweep-260.md) | Test suite đang đỏ — `RELEASE_CHECKLIST.md` chưa sweep "260 màn" | 1 | Must | P0 |
| [X17](tasks/X17-undo-rollback-lifetime-counters.md) | Undo không rollback counter đời → farm vô hạn achievement/quest/weekly/clan | 5 | Must | P1 |
| [X18](tasks/X18-pet-json-crash-boot.md) | `star_owned_pets` JSON hỏng → `onInit` throw → app không boot được | 2 | Must | P1 |
| [X19](tasks/X19-reset-progress-missing-keys.md) | `resetProgress()` bỏ sót 8 key + toàn bộ `remixBest` → progress ma sau reset | 3 | Must | P1 |
| [X20](tasks/X20-undo-loses-power-tile.md) | Undo xoá mất `powerKind` của power tile đã có trên bàn | 3 | Must | P1 |
| [X21](tasks/X21-undo-freeze-turns.md) | Undo không khôi phục `freezeTurnsLeft` → mất 1 lượt Freeze đã hoàn tác | 2 | Should | P2 |
| [X22](tasks/X22-pet-idle-reward-exploit.md) | Idle pet trả thưởng cho thời gian trước khi ấp + farm bằng chỉnh đồng hồ | 3 | Must | P1 |
| [X23](tasks/X23-booster-noop-consumes.md) | Swap cùng-ô và Shuffle no-op vẫn trả `true` → tiêu booster mà bàn không đổi | 2 | Should | P2 |
| [X24](tasks/X24-storage-write-amplification.md) | ~6 lần ghi `SharedPreferences` **mỗi cú tap** trên hot path | 5 | Must | P1 |
| [X25](tasks/X25-untrusted-code-payload-limits.md) | `decodeReplay`/challenge code không giới hạn payload → treo/OOM UI isolate | 3 | Should | P2 |
| [X26](tasks/X26-backup-key-hardcoded.md) | Khoá AES-GCM backup hard-code trong binary → giả mạo save được | 3 | Should | P2 |
| [X27](tasks/X27-defensive-guards.md) | Guard phòng thủ: crate trừ coin trước khi roll, `featuredLevelId` chia 0 | 2 | Could | P2 |
| [X28](tasks/X28-type-confused-save-bricks-app.md) | Save sai kiểu ném `TypeError` trong `_load()` → app không boot được, không có đường thoát | 3 | Must | P1 |
| [X29](tasks/X29-buffered-write-shadows-direct-write.md) | Buffer của X24 nuốt mọi lần ghi thẳng → undo/reset/import mất tác dụng trên đĩa | 2 | Must | P1 |
| [X30](tasks/X30-sky-shrine-aura-not-reactive.md) | Sky Shrine: thẻ chòm sao ngoài phạm vi `Obx` → gắn hào quang không đổi nhãn, không tháo ra được | 2 | Should | P2 |
| [X31](tasks/X31-hardcoded-vietnamese-in-raid-screen.md) | Chuỗi "xu" tiếng Việt hard-code trong màn Raid Boss → 21/22 locale hiện sai | 1 | Should | P2 |
| [X32](tasks/X32-chain-lock-leaks-into-side-modes.md) | `id % 6` trên id âm → chain lock rò vào Mirror Mode và Board of the Day | 1 | Should | P2 |

X28 đến X32 **không nằm trong kế hoạch ban đầu** — cả hai do test tìm ra sau
khi E6 đã "xong": X28 từ fuzz [[T4]], X29 từ integration test undo chạy trên
máy thật. Ghi lại ở đây để lần sau đọc bảng này không tưởng nhầm 12 dòng đầu
là toàn bộ những gì hardening tìm được.

**Tổng E6: 43 SP.** Thứ tự bắt buộc: X16 (unblock CI) → X17/X20/X21 (cùng
đụng `_saveUndo`, gộp 1 nhánh) → phần còn lại song song được.

---

## E7 — Test coverage cho vùng chưa cover (Must)

| ID | Tên | SP | Pri |
|----|-----|----|----|
| [T2](tasks/T2-controller-test-coverage.md) | 5 controller không có test nào | 8 | Must |
| [T3](tasks/T3-data-logic-test-gaps.md) | `wildcard_tile`, `pigments`, `mascot_skins`, 3 bảng bot leaderboard | 3 | Should |
| [T4](tasks/T4-save-corruption-fuzz.md) | Fuzz save hỏng + test `resetProgress` xoá đủ key | 5 | Must |

**Tổng E7: 16 SP.** T4 là lưới an toàn cho X18/X19 — làm cùng nhánh.

---

## E8 — Enhance: biến hệ vanity thành hệ có ý nghĩa (Should)

Chủ đề chung: game có ~20 hệ meta nhưng phần lớn **thuần trang trí**. Rẻ hơn
nhiều khi cho hệ đã có một lý do tồn tại, so với thêm hệ thứ 21.

| ID | Tên | SP | Pri |
|----|-----|----|----|
| [I81](tasks/I81-weather-gameplay-rules.md) | `WeatherKind` gắn luật gameplay thật (đang chỉ là skin) | 5 | Should |
| [I82](tasks/I82-star-pet-passive-skill.md) | Star Pet có passive nhẹ (đang thuần cosmetic) | 5 | Should |
| [I83](tasks/I83-constellation-prestige-tree.md) | Sky Shrine thành skill tree cho Prestige — NG+ có chiều sâu | 8 | Should |
| [I84](tasks/I84-home-next-best-action.md) | Home gợi ý "làm gì tiếp theo" thay vì liệt kê 14 mode | 5 | Must |
| [I85](tasks/I85-ftue-teach-core-rules.md) | FTUE dạy target/sao/combo, không chỉ 1 hint rồi tắt | 5 | Must |
| [I86](tasks/I86-comeback-digest.md) | Comeback bonus kèm digest "bạn đã bỏ lỡ gì" | 3 | Could |
| [I87](tasks/I87-milestone-story-reel.md) | Milestone Journal xuất share card "hành trình của bạn" | 3 | Could |
| [I88](tasks/I88-second-chance-no-ads.md) | Second chance khi kẹt — trả bằng coin, **không** quảng cáo | 5 | Should |

**Tổng E8: 39 SP.** I84 + I85 là 2 việc tác động retention lớn nhất trong
đợt này (xem "Điểm yếu" bên dưới).

---

## E9 — Tính năng mới / độc quyền (Could)

Chỉ chọn **1–2 cái** cho sprint đầu. Game đã có 14 mode; thêm mode thứ 15
mà không ai chơi là rủi ro chính của epic này.

| ID | Tên | SP | Pri | Độc quyền vì |
|----|-----|----|----|-----|
| [F16](tasks/F16-ghost-duel-async.md) | Ghost Duel bất đồng bộ — xem ghost đối thủ chạy trên bàn mình | 8 | Should | PvP-feel với zero backend, hạ tầng có sẵn 80% |
| [F17](tasks/F17-combo-bank-cross-mode.md) | Combo Bank — tiền tệ nối 14 side-mode đang là silo | 5 | Should | 14 mode hiện không mode nào nuôi mode nào |
| [F18](tasks/F18-puzzle-lab-daily-roulette.md) | Puzzle Lab Daily — board tự vẽ thành thử thách hằng ngày | 3 | Could | tận dụng editor đang bị bỏ không |
| [F19](tasks/F19-pigment-fusion.md) | Pigment Fusion — pha 2 pigment ra pigment hiếm | 5 | Could | crafting thay vì mở khoá tuyến tính |
| [F20](tasks/F20-boss-relay-coop.md) | Boss Relay — 2 người thay phiên đánh chung 1 boss HP pool | 13 | Could | co-op thật (chung mục tiêu) trên 1 máy |
| [F21](tasks/F21-mirror-draft.md) | Mirror Draft — tap của bạn nổ đối xứng ở nửa bàn đối thủ | 8 | Could | cùng-thắng-cùng-thua, dựa `mirror_board.dart` |
| [F22](tasks/F22-tile-dna-remix-lab.md) | Tile-DNA Lab — người chơi tự phối cơ chế special tile, share QR | 13 | Won't (đợt này) | crafting ở tầng *cơ chế*, không phải tầng vật phẩm |

**Tổng E9: 55 SP.** Đề xuất: lấy **F16 + F17**, để phần còn lại ở backlog.

---

## 5 điểm yếu lớn nhất hiện nay (đồng thuận cả 3 agent)

1. **Quá tải nhận thức, không có "next action".** 14 `GameMode` + ~20 hệ
   meta, `home_screen_controller.dart` chỉ *liệt kê* card chứ không *ưu
   tiên*. Người chơi mới không biết bắt đầu từ đâu. → [[I84]]
2. **FTUE chỉ dạy 1 nửa.** `game_screen_controller.dart:303-306` ép 1 hint ở
   level 1 rồi `hasSeenFtue = true` ngay tap đầu tiên. Không có gì dạy
   target score, cách tính sao, combo window, hay ý nghĩa special tile. →
   [[I85]]
3. **Phần lớn hệ meta là vanity.** Pets, constellations, pigments, 4 hệ
   cosmetic, weather — không cái nào chạm gameplay. Progression rộng nhưng
   phẳng. → [[I81]] [[I82]] [[I83]]
4. **14 side-mode là 14 silo.** Không mode nào nuôi mode nào; chơi Combo
   Rush không giúp gì cho campaign hay ngược lại. → [[F17]]
5. **Không có cứu trợ khi kẹt.** Bàn không refill (trừ Zen). Thua thì chỉ
   replay/quit. Chuẩn thể loại giải quyết bằng rewarded ad — ta đã chốt
   không dùng ads, nên cần đường coin. → [[I88]]

> Có ý kiến từ agent phụ rằng "không có đường doanh thu" là điểm yếu #1
> (`pubspec.yaml` không có `google_mobile_ads`/`in_app_purchase`). Đây là
> **quyết định sản phẩm có chủ đích**, không phải thiếu sót — đã chốt giữ
> miễn phí hoàn toàn. Ghi lại ở đây để lần audit sau không đề xuất lại.

## Sprint đề xuất (2 tuần/sprint, 1–2 dev)

| Sprint | Theme | Nội dung | SP |
|--------|-------|----------|-----|
| S9.1 | **Stop the bleeding** | X16 → X17/X20/X21 (1 nhánh `_saveUndo`) → X18/X19 + T4 | ~21 |
| S9.2 | **Hardening xong + đo được** | X22, X23, X24, X25, X26, X27 + T2, T3 | ~29 |
| S9.3 | **Onboarding & hướng đi** | I84, I85, I88 + I86 | ~18 |
| S9.4 | **Meta có ý nghĩa** | I81, I82 (+ I83 nếu còn chỗ) | ~10–18 |
| S9.5 | **Nội dung mới** | F16 + F17 | ~13 |

**Không kéo E9 lên trước E6.** Ba bug P1 trong E6 (X17 farm counter, X18
chặn boot, X19 reset không sạch) làm hỏng dữ liệu thật của người chơi; thêm
mode mới lên trên nền đó chỉ nhân rộng thiệt hại.

## Nguồn & phương pháp

- Đọc trực tiếp: `game_controller.dart` (2576 dòng, đọc hết), `pop_star_game.dart`,
  `game_screen_controller.dart`, `storage_service.dart`, toàn bộ `lib/logic`,
  `lib/data`, cây `test/`.
- `codex exec` (agent độc lập #1) — audit bug/tech-debt, 10 phát hiện,
  trong đó 6 cái vòng đọc thủ công bỏ sót (X17, X20, X21, X23, X25, X26).
- `claude -p` (agent độc lập #2) — audit product/idea, nguồn của phần lớn E9.
- `gemini` không dùng được: `IneligibleTierError` (client free-tier bị Google
  ngừng hỗ trợ, yêu cầu migrate sang Antigravity).
- Mọi bug trong E6 đã được đối chiếu lại với source thật trước khi ghi;
  claim "FTUE không tồn tại" từ agent #2 đã bị bác — FTUE có (X1), chỉ là
  quá mỏng, nên I85 viết lại thành "mở rộng" chứ không phải "xây mới".
