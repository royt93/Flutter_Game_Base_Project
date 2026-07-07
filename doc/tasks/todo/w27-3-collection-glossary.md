---
id: w27-3-collection-glossary
title: Audit nội dung trang bách khoa (Album/Collection) — đổi tên jargon + thêm mô tả
wave: 27
phase: 3
status: done
owner: claude
created: 2026-07-04
---

> 🟢 **2026-07-06** — **Bước 1–4 code xong**. `descKey` đã thêm vào `CollectionItem`
> (`lib/data/collection.dart`); 6 tên jargon đã đổi thành tên dễ hiểu cho cả 22 ngôn ngữ (giữ nguyên
> `id`/`threshold`/`colorIndex`/`nameKey`); 12 mô tả ngắn không-jargon đã thêm cho cả 22 ngôn ngữ qua
> `AppTranslations`. UI: `CollectionScreen` chuyển `StatefulWidget`, tap sticker (mở hay chưa) →
> `NeonDialog.overlay` hiện tên thật + mô tả (`_detailPanel`); chưa mở khoá thì thêm hint điểm
> `x/threshold`; đóng qua `coll_close` (tái dùng key có sẵn, không thêm key mới ngoài 6 tên + 12 mô
> tả + `coll_close` đã có). `flutter analyze` 0 issue, `flutter test --exclude-tags slow` 959/959
> pass (bao gồm `app_translations_test.dart`). Còn thiếu device-verify bằng mắt (tap 12 sticker trên
> device thật) để đóng phase.

> 🟢 **2026-07-06** — **Phát hiện lỗi sau lần code đầu**: 6 tên jargon lúc đầu chỉ được DỊCH NGHĨA
> (ví dụ `prism_shard` → "Mảnh Lăng Kính") nhưng vẫn còn jargon thật ("Lăng Kính"/"Prism" vẫn là từ
> khó hiểu với người không rành thiên văn/vật lý — không đạt mục tiêu "dễ hiểu"). Đã hỏi lại user qua
> `AskUserQuestion`, xác nhận hướng "Cả 2" vẫn giữ nhưng phải đổi tên THẬT SỰ dễ hiểu (không dịch
> jargon, mà thay hẳn bằng khái niệm đời thường). Đã sửa lại `AppTranslations` cho cả 22 ngôn ngữ, 6
> tên mới (bản EN): `prism_shard` → **Crystal Shard**, `nebula_core` → **Glowing Core**, `aurora_wing`
> → **Rainbow Wing**, `quasar_eye` → **Star Eye**, `pulsar_heart` → **Beating Heart**, `singularity` →
> **Infinity Gem** (giữ nguyên `id`/`threshold`/`colorIndex`/`nameKey`, chỉ đổi giá trị translate).
> `flutter analyze` 0 issue, `flutter test --exclude-tags slow` 959/959 pass. Device-verify bằng
> screenshot thật trên `R58MA6WYRPE` (fresh install, save data 0/12 — mọi sticker khoá): tap đủ 12/12
> sticker, xác nhận tên MỚI hiển thị đúng (không còn tên jargon cũ nào), mô tả không cắt chữ/vỡ
> layout, viền neon đúng màu theo `colorIndex`. **Đóng phase.**

# Phase 3 — Collection/Album glossary (đổi tên + mô tả, hướng "Cả 2" đã chốt)

"Trang bách khoa" = màn Album sưu tập (`CollectionScreen`/`CollectionController`,
`lib/data/collection.dart`). 12 sticker hiện tại (id · threshold · colorIndex, đọc trực tiếp từ
`kCollectionItems`):

| Nhóm | id | threshold | colorIndex |
|---|---|---|---|
| Dễ hiểu | `cyan_spark` | 30 | 0 |
| Dễ hiểu | `magenta_bloom` | 80 | 1 |
| Dễ hiểu | `lime_leaf` | 150 | 2 |
| Dễ hiểu | `amber_sun` | 240 | 3 |
| Dễ hiểu | `orange_ember` | 350 | 4 |
| Dễ hiểu | `violet_dusk` | 480 | 5 |
| **Jargon** | `prism_shard` | 640 | 0 |
| **Jargon** | `nebula_core` | 820 | 1 |
| **Jargon** | `aurora_wing` | 1030 | 2 |
| **Jargon** | `quasar_eye` | 1280 | 3 |
| **Jargon** | `pulsar_heart` | 1560 | 4 |
| **Jargon** | `singularity` | 1880 | 5 |

`CollectionItem` hiện chỉ có 4 field (`id`, `nameKey`, `threshold`, `colorIndex`) — **không có mô tả**.
Hướng đã chốt với user: **"Cả 2"** — vừa đổi tên 6 sticker jargon cho dễ hiểu hơn, vừa thêm mô tả cho
đủ 12 sticker (không chỉ 6 jargon, để nhất quán trải nghiệm).

## Bước 1 — Data model
- [x] Thêm field `descKey` vào `CollectionItem` (`lib/data/collection.dart`), tương tự pattern
  `nameKey` hiện có (key trỏ vào `AppTranslations`).
- [x] Cập nhật `kCollectionItems` — mỗi item thêm `descKey` (12 key mới, ví dụ
  `collection_desc_cyan_spark`).

## Bước 2 — Đổi tên 6 sticker jargon (giữ `id`/threshold/colorIndex, chỉ đổi `nameKey` hiển thị)
- [x] `prism_shard` → tên dễ hiểu hơn (gợi ý: "Mảnh Lăng Kính" — có thể tinh chỉnh khi thực thi).
- [x] `nebula_core` → gợi ý: "Lõi Tinh Vân".
- [x] `aurora_wing` → gợi ý: "Cánh Cực Quang".
- [x] `quasar_eye` → gợi ý: "Mắt Chuẩn Tinh" (hoặc diễn giải hoàn toàn khác nếu vẫn khó hiểu — cân
  nhắc lúc thực thi, không cần hỏi lại nếu rõ ràng hơn bản gốc).
- [x] `pulsar_heart` → gợi ý: "Tim Sao Xung".
- [x] `singularity` → gợi ý: "Điểm Kỳ Dị" (giữ phần nào chất "đỉnh cao" vì đây là sticker hiếm nhất,
  threshold cao nhất 1880).

## Bước 3 — Mô tả cho đủ 12 sticker (multi-language)
- [x] Viết 1 câu mô tả ngắn (không jargon) cho từng sticker — ví dụ gợi mở lý do/cảm giác đạt được
  (không chỉ định nghĩa từ), phù hợp giọng game.
- [x] Thêm vào `_extraEn`/`_extraVi` (12 key mới) + map `_wXXByLang` mới (20 ngôn ngữ khác), theo
  convention hiện có trong `AppTranslations`.

## Bước 4 — UI hiển thị mô tả
- [x] Khảo sát lại `CollectionScreen._cell()` hiện tại (3-column, `childAspectRatio: 0.78`, font 9px —
  đã chật, không nhồi thêm text được). Chọn hướng hiển thị mô tả:
  - Tap vào cell → mở `NeonDialog.overlay` hiện tên + mô tả đầy đủ (khớp pattern dialog full-screen
    Flame hiện có, không dùng `Get.dialog`/`showDialog`).
  - (Hoặc) icon "i" nhỏ góc cell → cùng cơ chế dialog trên.
- [x] Đảm bảo dialog xem được cả sticker CHƯA đạt threshold (mô tả vẫn hữu ích để biết mục tiêu, có
  thể ẩn/mờ ảnh sticker nếu theo pattern hiện có của màn hình).

## Acceptance
- [x] `flutter analyze` 0 issue.
- [x] `flutter test --exclude-tags slow` xanh, gồm `app_translations_test.dart` (tỉ lệ khác-English
  ≥79-80% với 12 key mô tả mới).
- [x] Device-verify: tap từng sticker trong Album → thấy tên mới (không còn 6 tên jargon cũ) + mô tả
  hiển thị đầy đủ, không bị cắt chữ/vỡ layout.

## Lưu ý
- 🚫 KHÔNG commit (user tự commit) — xem [[code-on-main-only]].
- Không đổi `id`/`threshold`/`colorIndex` (đây là dữ liệu progress đã lưu — đổi sẽ lệch save cũ của
  người chơi hiện tại).
- Nếu cần đổi UI grid (cột/tỉ lệ) để dễ đọc hơn thay vì chỉ dùng dialog, ghi rõ quyết định vào progress
  note (`>`) của file này trước khi sửa, không cần tách task riêng.
