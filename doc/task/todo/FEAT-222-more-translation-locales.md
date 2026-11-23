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

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Chốt danh sách ngôn ngữ bản đầu và NGƯỜI DUYỆT bản dịch với owner; đề xuất bắt đầu 1 ngôn ngữ (es) để đo chi phí. Không thêm ngôn ngữ chưa có người duyệt.
- [ ] 2. Thêm một `Map` locale đủ 11 key (và key mới từ FEAT-232 nếu đã vào); `flutter test test/core/app_translations_test.dart` (parity) phải pass.
- [ ] 3. Kiểm glyph Baloo2 cho ngôn ngữ đó (nhất là th, ja): chạy `pseudo_locale`/text scale 2.0 trên các màn example, ghi font fallback và tràn nếu có.
- [ ] 4. Golden theo locale: nếu thêm baseline, sinh bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi, KHÔNG sinh trên macOS.
- [ ] 5. Cập nhật `AppTranslations.supported`, README/CHANGELOG (**Behavior change** nếu `LocaleService` cần nhận biết locale mới); `LocaleService` vẫn mặc định English (BUG-94).
- [ ] 6. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate; ghi trạng thái duyệt từng locale, chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Mỗi locale mới đủ key (parity test pass).
- [ ] Có người duyệt được ghi tên/vai trò hoặc locale được đánh dấu "chưa duyệt".
- [ ] Máy mới vẫn mở bằng English.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/app_translations_test.dart test/core/locale_service_test.dart`
