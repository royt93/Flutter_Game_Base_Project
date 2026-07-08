---
id: w27-OVERVIEW
title: Wave 27 — Verify 1A/1B/1C + ALL-CAPS titlecase + Collection glossary
wave: 27
status: done
owner: claude
created: 2026-07-05
---

> 🟢 **2026-07-05** — **Phase 1 hoàn tất**: 1A (2026-07-04), 1B (ColorRush refill-bias, mật độ màu
> nóng/đổi màu/không lag) và 1C ("Thử Thách" — icon sau Gold, lượt -15%, thưởng +51%, tắt trả về
> bình thường, không leak sang campaign) đều đã device-verify xong (chi tiết ở
> [[w27-1-device-verify-1abc]]). Không có code nào bị đụng — chỉ verify bằng device. Còn 1 mục tuỳ
> chọn ở 1A (verify thêm 1 stage chẵn) đã **skip theo quyết định user** (mất quá nhiều thời gian, không
> bắt buộc).

> 🟢 **2026-07-06** — **Phase 2 code xong**: 2050 giá trị ALL-CAPS → Title Case trong 15 ngôn ngữ có
> case (`app_translations.dart`). 33 test fail phát sinh do assertion còn literal ALL-CAPS cũ — đã sửa
> assertion trong file test tương ứng (không revert translation). `flutter analyze` 0 issue,
> `flutter test --exclude-tags slow` 959/959 pass (chi tiết ở [[w27-2-allcaps-titlecase]]). Còn thiếu
> device-verify bằng mắt (Home + HUD in-game).

> 🟢 **2026-07-06** — **Phase 2 device-verify xong, đóng phase**. Phát hiện và sửa 2 bug ALL-CAPS ngoài
> phạm vi raw-translation audit (bị render sai qua code, không phải giá trị translation gốc):
> 1. Header "REWARDS" — `.toUpperCase()` cứng trong `_sectionLabel` (Home Screen) → đã xoá.
> 2. Badge "PHASE 1/2/3" trong HUD "Neon Boss" — literal cứng bypass i18n tại `_bossWeakHint`
>    (`game_screen.dart`) → đã thêm key `boss_phase` cho **cả 22 ngôn ngữ** trong `AppTranslations`,
>    wire `.tr` vào thay 3 literal. Sửa 2 test assertion liên quan (`test/widget/screens_test.dart`).
> `flutter analyze` 0 issue, `flutter test --exclude-tags slow` 959/959 pass. Device-verify bằng
> screenshot thật trên `118743744X002560`: Home Screen và HUD "Neon Boss" đều sạch Title Case, không
> có ad che UI. Chi tiết đầy đủ ở [[w27-2-allcaps-titlecase]].

> 🟢 **2026-07-06** — **Phase 3 code xong**: `descKey` thêm vào `CollectionItem`; 6 tên jargon
> (`prism_shard`, `nebula_core`, `aurora_wing`, `quasar_eye`, `pulsar_heart`, `singularity`) đã đổi
> tên dễ hiểu cho cả 22 ngôn ngữ (giữ `id`/`threshold`/`colorIndex`/`nameKey`); 12 mô tả ngắn
> không-jargon đã thêm cho cả 22 ngôn ngữ. UI: `CollectionScreen` chuyển `StatefulWidget`, tap
> sticker (mở hay chưa) → `NeonDialog.overlay` hiện tên thật + mô tả, thêm hint điểm nếu chưa mở
> khoá. `flutter analyze` 0 issue, `flutter test --exclude-tags slow` 959/959 pass. Còn thiếu
> device-verify bằng mắt (tap 12 sticker) — chi tiết ở [[w27-3-collection-glossary]].

> 🟢 **2026-07-06** — **Phase 3 device-verify xong, đóng phase**. Phát hiện lỗi sau lần code đầu: 6
> tên jargon lúc đầu chỉ DỊCH NGHĨA (vẫn còn jargon, chưa thực sự dễ hiểu) — đã hỏi lại user qua
> `AskUserQuestion`, sửa lại đúng theo hướng "thay hẳn khái niệm" cho cả 22 ngôn ngữ: `prism_shard` →
> **Crystal Shard**, `nebula_core` → **Glowing Core**, `aurora_wing` → **Rainbow Wing**, `quasar_eye`
> → **Star Eye**, `pulsar_heart` → **Beating Heart**, `singularity` → **Infinity Gem**. Device-verify
> đủ 12/12 sticker trên `R58MA6WYRPE`: tên mới hiển thị đúng, mô tả không cắt chữ, viền neon đúng màu.
> Chi tiết ở [[w27-3-collection-glossary]].

# Wave 27 — Tổng hợp

| Phase | Hạng mục | File | Loại | Ưu tiên | Đụng engine? | Trạng thái |
|---|---|---|---|---|---|---|
| 1 | Device-verify 1A/1B/1C (Wave 25.1) | [[w27-1-device-verify-1abc]] | Verify (không sửa code) | Cao | Không | **Done** |
| 2 | ALL-CAPS → title case, mọi ngôn ngữ | [[w27-2-allcaps-titlecase]] | i18n string audit | Trung | Không | **Done** |
| 3 | Audit jargon Album (Collection) — đổi tên + mô tả | [[w27-3-collection-glossary]] | Content + UI nhỏ | Trung | Không | **Done** |

## Mô tả từng phase
- **Phase 1**: 1A đã unit-test + device-verify xong (2026-07-04); 1B (ColorRush refill-bias) và 1C
  ("Thử Thách" hard variant) đã code xong + unit test xanh (969 passed) nhưng chưa nhìn mắt trên
  device. Task này chỉ verify, không sửa code trừ khi phát hiện lệch.
- **Phase 2**: Nhiều string UI đang ALL-CAPS (nút, header, HUD boss). Đã đổi sang Title Case cho tự
  nhiên, giữ semantics, không đổi key. `flutter analyze`/test đã xanh, device-verify xong, đóng phase.
- **Phase 3**: "Trang bách khoa" = Album sưu tập, 12 sticker, 6 cái tên jargon (prism_shard,
  nebula_core, aurora_wing, quasar_eye, pulsar_heart, singularity). Hướng đã chốt "Cả 2": đổi tên
  jargon + thêm mô tả cho đủ 12 sticker, multi-language. Đã thêm field `descKey` vào `CollectionItem`
  và UI dialog tap-detail để hiển thị (grid cell quá chật để nhồi thêm text). `flutter analyze`/test
  đã xanh — còn thiếu device-verify bằng mắt để chốt Acceptance cuối.

## Ghi chú trung thực về hiện trạng
- Phase 1: chỉ verify bằng mắt, không đụng code (code/test đã chốt từ trước).
- Phase 2: đã sửa code thật (string translation ALL-CAPS → Title Case) + device-verify xong, đóng
  phase.
- Phase 3: đã sửa code thật (model field, translation, UI dialog mới) — `flutter analyze`/test xanh,
  còn thiếu device-verify bằng mắt để đóng phase.

## Nguyên tắc (NHẮC)
- 🚫 KHÔNG git commit trong bất kỳ phase nào — user tự commit ([[code-on-main-only]]).
- R3: chỉ có device R5CX613VZBR khi cần verify — dùng luôn, đã thông báo trước.
- R4: dừng ngay nếu ad che UI trong screenshot verify (app hiện không có ad SDK thật).
- R1: dùng `AskUserQuestion` cho quyết định có lựa chọn (đã ghi cụ thể ở Phase 2, Bước 2).
