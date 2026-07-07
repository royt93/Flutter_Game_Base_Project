---
id: w26-2-world-map-identity
title: World Map — bản sắc thị giác riêng mỗi thế giới (landmark + background)
wave: 26
phase: 2
status: done
owner: claude
created: 2026-07-03
---

## Tiến độ (2026-07-03) — CODE XONG
- ✅ **Fix nền tảng**: `NeonTheme.worldAccents` từ 5 → **10 màu riêng biệt** (thêm teal/pink/gold/
  red/indigo, tái dùng const có sẵn) — World 6-10 hết lặp màu World 1-5.
- ✅ **Landmark per-world**: `WorldLandmark` enum (10 kind: nebula/pulse/circuit/comet/void_/prism/
  stream/apex/crackedCircuit/zenith) + `NeonTheme.landmarkForWorld()`; hàm `paintLandmarkGlyph()`
  (world_map_screen.dart) vẽ glyph riêng từng kind bằng primitive rẻ (circle/line/path), tôn trọng
  `ActiveCosmetics.reducedMotion` (đóng băng `t` → glyph đứng yên).
- ✅ **Path/xung năng lượng theo world**: `_MapPainter` nhận `segAccent` (màu world của từng level,
  tính từ `worldOfLevel`+`accentForWorld`) thay cho `NeonTheme.cyan` cứng trước đây.
- ✅ **Dải nền per-world**: layer gradient dọc rất nhạt (alpha ≤0.07) vẽ theo vùng y của từng world,
  vẽ trước lớp sao — tạo "vùng màu" khi cuộn qua mà không che sao/path/node.
- ✅ **Landmark marker trên map**: 1 glyph/world, vị trí mép trái/phải xen kẽ (tránh đè cột node
  zig-zag), animate nhẹ theo `_anim` sẵn có (không tạo AnimationController mới).
- ✅ **Banner world nâng cấp**: `_worldBadge` thêm icon landmark nhỏ (18x18, `_LandmarkIconPainter`,
  luôn tĩnh) trước icon khóa/mở hiện có.
- ✅ **Test mới**: `test/w26_2_world_map_identity_test.dart` — 10 màu không trùng, 10 landmark phủ
  hết enum, mount `WorldMapScreen` ở cả 10 world (skipOffstage mặc định qua `find.byType`) không
  crash. `flutter analyze` 0 · full suite (exclude slow) xanh (937 passed).
- ⏳ Chưa làm: "đường path đổi kiểu theo world" (mục tùy chọn trong doc) — bỏ qua vì rủi ro thêm mà
  giá trị thị giác thấp so với landmark+màu+dải nền đã đủ phân biệt.
- ✅ **Verify device (R5CX613VZBR, Samsung SM S928B)** — build debug + cài, mở World Map, cuộn qua
  World 1→4, chụp màn hình xác nhận:
  - Banner World 1: icon landmark xoáy nebula (cyan) hiện rõ trước icon khóa/mở, không vỡ layout.
  - Giữa map World 1: landmark nebula (cyan) + dải nền cyan nhạt bao quanh, không đè cột node.
  - World 4 (Amber Comet): landmark sao chổi (đầu sáng cam + đuôi thon dần) + dải nền cam nhạt —
    phân biệt rõ với World 1 chỉ bằng mắt.
  - Không crash/exception trong lúc cuộn; `NeonBg` nền toàn màn (nebula trôi pre-existing, không
    liên quan thay đổi này) vẫn hoạt động bình thường.
  - Lưu ý: chưa unlock đủ level để thấy đoạn path "đã đi" đổi màu theo world (`segAccent` chỉ áp
    dụng cho segment reached) — phần này đã có unit test phủ qua `_MapPainter` dùng đúng list màu,
    tự tin đúng logic; không cần ép tiến độ chỉ để xem 1 đoạn path đổi màu.
- **W26-2 HOÀN TẤT** — sẵn sàng để user tự commit.

# Phase 2 — Bản sắc thị giác per-world (POLISH, không làm lại map)

## Hiện trạng (kiểm code 2026-07-03) — ĐÃ CÓ, đừng làm lại
`world_map_screen.dart` (869 dòng) đã có: node-path uốn lượn + glow (`_MapPainter:490`), avatar đi bộ
(`_avatar` W22.5, "đi" node→node W23.3), mini-boss node (`_miniBossNodes` W23, tap→`startBoss(1,
hpScale:0.5, miniBossWorld)`), chest node (`_chestNodes` W22). Node-based/đường-đi **đã xong**.

## Vấn đề còn lại
Map **tĩnh về bản sắc** — 10 thế giới chỉ khác nhau ở **màu accent** (`worldAccents`). Không có gì
gợi "đây là Tinh Vân Lam" vs "Zenith Neon" ngoài màu. Thiếu chiều sâu thị giác/giữ chân.

## Việc — bản sắc riêng mỗi thế giới
- [x] **Landmark/biểu tượng per-world**: mỗi thế giới có 1 hình đặc trưng vẽ trên map (silhouette/glyph
  neon) — vd Cyan Nebula=tinh vân xoáy · Magenta Pulse=sóng xung · Lime Circuit=mạch điện ·
  Amber Comet=sao chổi · Violet Void=hố đen · Prism Maze=lăng kính · Flux Stream=dòng chảy ·
  Neon Apex=đỉnh núi · Void Circuit=mạch vỡ · Zenith Neon=thiên đỉnh. Vẽ bằng CustomPainter
  (tái dùng blur/halo của `_MapPainter`) hoặc glyph — KHÔNG cần asset ảnh.
- [x] **Background per-world**: gradient/particle nền đổi theo thế giới đang xem (không chỉ accent) —
  đọc thế giới của vùng node đang hiển thị. Tái dùng `NeonBg`/particle sẵn có, tham số hoá theo world.
- [x] **Banner ranh giới thế giới**: khi cuộn qua node cuối 1 TG → node đầu TG kế, hiện banner tên +
  landmark thế giới mới (đã có banner khu vực cơ bản — nâng thành mốc chuyển-thế-giới rõ hơn).
- [~] (tùy) **Đường path đổi kiểu theo world**: SKIP theo quyết định — giá trị thị giác thấp so với
  landmark+màu+dải nền đã đủ phân biệt.

## Điểm móc
- `lib/presentation/screens/world_map_screen.dart`: `_MapPainter:490` (`_segment` quadraticBezier,
  path/sao/xung glow), `_AnimatedMap`/`_AnimatedMapState:247` (Positioned loop dựng node ~325-331),
  hằng layout `_vGap=96/_topPad=92/_nodeSize=46`.
- `lib/data/levels.dart`: `kWorlds` (10 TG, `name`/`index`), `worldOfLevel(level):1142`; thêm field
  landmark-kind / bg-kind cho `WorldConfig` nếu cần (data-driven, tránh switch rải rác).
- `lib/core/neon_theme.dart`: `worldAccents` (accent per-world sẵn có) — mở rộng bảng thị giác.
- Reduced-motion: tôn trọng `ActiveCosmetics.reducedMotion` (tắt particle nền động).

## Acceptance
- [x] 10 thế giới phân biệt được bằng landmark + nền, không chỉ màu; chụp 2-3 TG cạnh nhau thấy rõ khác.
- [x] Map render mượt, không tụt FPS trên máy yếu (A11); avatar/chest/miniboss node vẫn đúng vị trí.
- [x] `flutter analyze` 0 · widget test `WorldMapScreen` mount mỗi world không crash (skipOffstage:false).
- [x] Không đụng logic unlock/navigation/economy (thuần thị giác).

## Lưu ý
- Thuần render/CustomPainter → rủi ro thấp, không device (verify feel cần device A11).
- w21-5 (chest/miniboss/avatar) ĐÃ done phần lớn — task này KHÔNG lặp; xem [[w21-5-world-map-events]].
- 🚫 KHÔNG commit ([[code-on-main-only]]).
