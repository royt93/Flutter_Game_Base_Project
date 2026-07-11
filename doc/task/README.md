# Pop Star Blast — Scrum Board

Nguồn sự thật cho toàn bộ công việc revamp. Mỗi story viết để **1 junior dev
cầm là làm được**: có mô tả, acceptance criteria, subtask kèm gợi ý file, ước
lượng, ưu tiên, phụ thuộc, Definition of Done.

> Trạng thái game trước đợt này: MVP chạy được (200 level, pop/gravity/collapse,
> 3 booster, 6 screen, i18n 22 ngôn ngữ). UI neon-dark tĩnh, thiếu animation.
> Kiến trúc: pure logic (`lib/logic`) → data (`lib/data`) → Flame (`lib/game`)
> → GetX (`lib/presentation`). Xem `doc/feat.md`.

## Quyết định art-direction (đã chốt)

**Pivot bright-casual (Candy-Crush style).** Bỏ nền đen thuần → nền sáng ấm,
palette pastel + neon accent, mascot ngôi sao, juice/animation nặng. Redesign
gần như toàn bộ art UI. Đây là ràng buộc xuyên suốt E1–E3.

## Epics

| ID | Epic | Item gốc | Ưu tiên |
|----|------|----------|---------|
| E1 | Art Revamp — Bright Casual Pivot | 4, 5 | Must |
| E2 | Gameplay Animation & Juice (pop/rơi/collapse) | 1 | Must |
| E3 | Game-wide Animation & Transitions | 2 | Should |
| E4 | Test Coverage đầy đủ (unit/widget/integration) | 3 | Must |
| E5 | Docs & Markdown Audit | 6 | Should |

File chi tiết: `epic-01-art-revamp.md` … `epic-05-docs-audit.md`,
index đầy đủ ở `backlog.md`.

## Sprint plan (đề xuất: 3 sprint × 2 tuần, 1–2 junior + 1 review)

| Sprint | Theme | Nội dung chính |
|--------|-------|----------------|
| S1 | Foundation & Juice | E1 design tokens + theme + bg + buttons · E2 pop/drop/collapse anim · E5 audit doc · E4 hạ tầng test + unit logic |
| S2 | Screens & Motion | E1 redesign từng screen + dialog · E3 transition/HUD/coin motion · E4 widget test |
| S3 | Celebrate & Harden | E1 mascot + celebration · E3 win/lose juice + particle · E4 integration + golden test · QA polish |

Thứ tự bắt buộc: **E1-S1 (design tokens) là chặn** cho phần lớn E1/E3. E2 (logic
animation) chạy song song được trên visual tạm. E5 độc lập, làm sớm để lấy đà.

## Quy ước

**Ước lượng** — Fibonacci story point: 1 (vài giờ), 2, 3 (1 ngày), 5 (2–3 ngày),
8 (gần 1 tuần), 13 (chẻ nhỏ trước khi làm).

**Ưu tiên** — MoSCoW: Must / Should / Could / Won't.

**Trạng thái** — 📋 To Do · 🟡 In Progress · 👀 In Review · ✅ Done · ⏸️ Blocked.

**Nhánh** — `epic/<id>-<slug>` cho feature lớn, `story/<story-id>-<slug>` cho story.
Commit: conventional (`feat:`/`fix:`/`test:`/`docs:`/`refactor:`).

## Definition of Done (áp cho MỌI story)

- [ ] Code theo convention repo (đọc `CLAUDE.md`), khớp style xung quanh.
- [ ] `flutter analyze` → **0 issue**.
- [ ] `flutter test --exclude-tags slow` → **xanh**; story có logic mới kèm test.
- [ ] Với story UI/anim: chụp screenshot/quay clip trên device thật, đính vào PR.
- [ ] Không lộ raw i18n key; chuỗi mới thêm vào `AppTranslations` (en + vi tối thiểu).
- [ ] Không hạ độ phủ test hiện có; không thêm dependency mới nếu vài dòng tự làm được.
- [ ] Cập nhật `doc/feat.md` nếu đổi/ thêm feature nhìn thấy được.
- [ ] Được review (👀) và giải quyết hết comment trước khi ✅.

## Definition of Ready (trước khi kéo story vào sprint)

- AC rõ, đo được. Phụ thuộc đã xong hoặc song song được. Đủ nhỏ (≤ 8 điểm).
- Có gợi ý file/nơi sửa. Nếu cần asset art → asset sẵn sàng hoặc dùng placeholder rõ.
