---
id: w27-OVERVIEW
title: Wave 27 — Verify 1A/1B/1C + ALL-CAPS titlecase + Collection glossary
wave: 27
status: todo
owner: claude
created: 2026-07-05
---

> 🟢 **2026-07-05** — **Phase 1 hoàn tất**: 1A (2026-07-04), 1B (ColorRush refill-bias, mật độ màu
> nóng/đổi màu/không lag) và 1C ("Thử Thách" — icon sau Gold, lượt -15%, thưởng +51%, tắt trả về
> bình thường, không leak sang campaign) đều đã device-verify xong (chi tiết ở
> [[w27-1-device-verify-1abc]]). Không có code nào bị đụng — chỉ verify bằng device. Còn 1 mục tuỳ
> chọn ở 1A (verify thêm 1 stage chẵn) đã **skip theo quyết định user** (mất quá nhiều thời gian, không
> bắt buộc). Sẵn sàng chuyển sang Phase 2 khi có chỉ đạo.

# Wave 27 — Tổng hợp

| Phase | Hạng mục | File | Loại | Ưu tiên | Đụng engine? | Trạng thái |
|---|---|---|---|---|---|---|
| 1 | Device-verify 1A/1B/1C (Wave 25.1) | [[w27-1-device-verify-1abc]] | Verify (không sửa code) | Cao | Không | **Done** |
| 2 | ALL-CAPS → title case, mọi ngôn ngữ | [[w27-2-allcaps-titlecase]] | i18n string audit | Trung | Không | Todo |
| 3 | Audit jargon Album (Collection) — đổi tên + mô tả | [[w27-3-collection-glossary]] | Content + UI nhỏ | Trung | Không | Todo |

## Mô tả từng phase
- **Phase 1**: 1A đã unit-test + device-verify xong (2026-07-04); 1B (ColorRush refill-bias) và 1C
  ("Thử Thách" hard variant) đã code xong + unit test xanh (969 passed) nhưng chưa nhìn mắt trên
  device. Task này chỉ verify, không sửa code trừ khi phát hiện lệch.
- **Phase 2**: Nhiều string UI đang ALL-CAPS (nút, header, HUD boss). Đổi sang title case cho tự
  nhiên, giữ semantics, không đổi key. Cần `AskUserQuestion` để chốt cách xử lý acronym (nếu có)
  trước khi sửa hàng loạt.
- **Phase 3**: "Trang bách khoa" = Album sưu tập, 12 sticker, 6 cái tên jargon (prism_shard,
  nebula_core, aurora_wing, quasar_eye, pulsar_heart, singularity). Hướng đã chốt "Cả 2": đổi tên
  jargon + thêm mô tả cho đủ 12 sticker, multi-language. Cần thêm field `descKey` vào
  `CollectionItem` và UI dialog tap-detail để hiển thị (grid cell hiện quá chật để nhồi thêm text).

## Ghi chú trung thực về hiện trạng
- Cả 3 phase đều **chưa động code** — chỉ mới rã task doc trong phiên này.
- Phase 1 rủi ro thấp nhất (chỉ verify bằng mắt, code/test đã chốt từ trước).
- Phase 2/3 cần sửa code thật (string, model field, UI) — nên làm tuần tự, không làm đồng thời để
  tránh xung đột file (`app_translations.dart` bị đụng ở cả 2 phase).

## Nguyên tắc (NHẮC)
- 🚫 KHÔNG git commit trong bất kỳ phase nào — user tự commit ([[code-on-main-only]]).
- R3: chỉ có device R5CX613VZBR khi cần verify — dùng luôn, đã thông báo trước.
- R4: dừng ngay nếu ad che UI trong screenshot verify (app hiện không có ad SDK thật).
- R1: dùng `AskUserQuestion` cho quyết định có lựa chọn (đã ghi cụ thể ở Phase 2, Bước 2).
