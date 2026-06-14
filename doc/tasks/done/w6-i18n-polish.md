---
id: w6-i18n-polish
title: Dọn nợ i18n + polish
wave: 6
status: done
owner: claude
---

# Dọn nợ i18n + polish

## Đã làm
- **`world_n` cho đủ 22 ngôn ngữ**: trước chỉ en+vi (20 ngôn ngữ fallback
  English). Nay 20 ngôn ngữ có bản dịch riêng (qua lớp merge `_w6ByLang`).
- **Tên 5 thế giới i18n** (`world_name_1..5`): thêm khoá + dịch đủ 22 ngôn ngữ
  (Cyan Nebula → Tinh Vân Lam / 青色星云 / ...). `level_select` + `world_map`
  dùng `worldNameKey(w.index).tr` thay vì `w.name` hard-coded.
- **Kiến trúc i18n gọn**: thêm lớp `_w6ByLang` (20 map `_w6Es.._w6Bn`) merge sau
  `_extraByLang` — KHÔNG sửa 22 base map. en/vi nằm trong `_extraEn/_extraVi`.
- **Verify polish**: đếm ngược hồi mạng ở Home (`_LivesChip`) đã tự tick
  (`Timer.periodic` + `setState`) → nợ Wave 4.2 coi như đã giải quyết.

## Kết quả
0 analyzer issue · test parity i18n pass (mọi locale đủ khoá, placeholder `@n`
giữ nguyên) · 140 unit/widget test pass.
