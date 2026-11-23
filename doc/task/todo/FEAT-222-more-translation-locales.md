---
id: FEAT-222
title: "Mở rộng app_translations từ 2 lên thêm vài ngôn ngữ (es, pt-BR, id, th, ja) cho 11 key gốc"
type: feature
layer: lib/core
priority: P4
effort: M
source: "Đề xuất của Claude 2026-11-23, owner chọn đưa vào backlog"
---

Kit nhắm khán giả toàn cầu (xem BUG-94: máy mới luôn mở bằng English) nhưng `AppTranslations.supported` chỉ có `en`, `vi`. CLAUDE.md nói file này là mẫu để consumer tự thêm ngôn ngữ.

## Rủi ro đã nêu

Dịch máy cần người bản ngữ duyệt; tăng bề mặt bảo trì; golden theo locale (`locale-vi` hiện là biến thể) có thể cần thêm baseline Linux qua workflow `regenerate-goldens.yml` (không sinh golden trên macOS).

## Phạm vi đề xuất

- Thêm locale vào `AppTranslations` (một `Map` mỗi locale), mỗi locale đủ 11 key; `test/core/app_translations_test.dart` đã ép parity key nên thiếu key là đỏ ngay.
- Kiểm: font Baloo2 có phủ glyph không (Thái, Nhật có thể thiếu: fallback font hệ thống, cần kiểm tra overflow bằng `pseudo_locale`/text scale), RTL không cần ở nhóm này.
- Không thêm ngôn ngữ nào chưa có người duyệt; ghi rõ trạng thái duyệt từng locale.

## Câu hỏi mở

Danh sách ngôn ngữ ưu tiên và ai duyệt bản dịch. Có thể bắt đầu với 1 ngôn ngữ (es) để đo chi phí trước khi mở rộng.
