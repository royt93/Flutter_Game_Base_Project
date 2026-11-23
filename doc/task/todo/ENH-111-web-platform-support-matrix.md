---
id: ENH-111
title: "Web: chốt mức hỗ trợ cho từng nhóm service còn lỗi trên Chrome"
type: enhancement
layer: lib/core, docs
priority: P2
effort: M
source: "Khảo sát web 2026-11-23: kit biên dịch được cho web (sau BUG-140), 3925 test pass trên Chrome, 51 đỏ ở lần đo đầu. Owner định hướng tập trung SDK game + web + widget common + helper."
---

## Bằng chứng (đã đo, không suy đoán)

- `flutter build web` của app thử dùng kit (import cả 121 thư viện export) pass.
- `flutter test --platform chrome --exclude-tags slow test/core test/widget/common test/presentation`: 3925 pass, 51 đỏ ở lần đo đầu (sau khi đã sửa 3 literal). `test/tool/*` loại ra vì dùng `dart:io`, đúng với CLI.
- 51 đỏ chia nhóm (số test): `audio_manager_test` 20, `reminder_service_test` 7, `wake_lock_service_test` 5, `smart_reminder_scheduling_test` 5, `app_version_gate_test` 3, `kit_bootstrap_test` 3, `share_helper_test` 2, `level_up_overlay_test` 1, và 5 test lẻ (`fnv1a`, `experiment_bucketing`, `safe_json`, `shadow_activation`, `candy_slider`).
- BUG-140 đã sửa 3 trong 51: `fnv1a_test`, `experiment_bucketing_service_test` và `safe_json_test` (`asIntOr` với `Infinity`) (phân phối bucket sai vì hash sai, xem BUG-140). Còn lại ước tính 48, **chưa chạy lại toàn bộ suite sau khi sửa** nên con số này là suy ra từ lần đo đầu trừ 3 test đã xác nhận pass; cần chạy lại để có số chính thức.
- Lệnh tái hiện: `flutter test --platform chrome --exclude-tags slow test/core test/widget/common test/presentation`.

## Phân loại nguyên nhân

| Nhóm | Dấu hiệu | Nghi vấn |
| --- | --- | --- |
| `audio_manager_test` (20), `level_up_overlay_test` (1) | `Unsupported operation: _Namespace` từ `Directory.systemTemp` / `File.openSync` | Test dùng `dart:io` (file tạm, đọc source); không phải lỗi kit. Cần gắn tag hoặc skip trên web. |
| `reminder_service_test` (7), `smart_reminder_scheduling_test` (5) | `initialize` không xuất hiện trước `requestNotificationsPermission`; `Bad state: No element` | `flutter_local_notifications` không có kênh native trên web; kit có thể cần đường đi riêng cho web. Chưa rõ là hạn chế nền tảng hay bug thứ tự gọi. |
| `wake_lock_service_test` (5), `kit_bootstrap_test` (3), `app_version_gate_test` (3) | `TimeoutException 30s` | Test treo trên Chrome; nghi cùng một nguyên nhân (plugin/async không hoàn tất) chứ chưa xác nhận. |
| `share_helper_test` (2) | `captureBoardPng` leak Picture / `shareJourneyCard` | Có thể là khác biệt renderer web; cần đọc kỹ trước khi kết luận. |
| lẻ (2 còn lại) | `shadow_activation` (500 vs 500.0), `candy_slider` (semantics) | Khác biệt số học/định dạng của JS (số nguyên và double là một kiểu); từng ca cần phân biệt "test giả định VM" và "bug kit". |

## Phạm vi

1. Với mỗi nhóm: xác định là hạn chế nền tảng chính đáng, test giả định VM, hay bug kit. Chỉ nhóm "bug kit" mới sửa code; hai nhóm còn lại sửa test (tag `vm-only` hoặc skip có lý do) hoặc ghi giới hạn.
2. Owner chốt mức hỗ trợ web mong muốn: `PlatformCapabilityRegistry` đang coi web là "không hỗ trợ" cho 4 domain; đối chiếu lại với kết quả đo thật.
3. Cập nhật `docs/qa/capability_evidence_matrix.md` và README với bảng "chạy được / không chạy trên web".

## Câu hỏi owner cần chốt

- Mức hỗ trợ web: (a) chỉ biên dịch và chạy phần lõi (storage, i18n, theme, widget, engine), service nền tảng như thông báo, wakelock, audio chỉ no-op có tài liệu; (b) hỗ trợ đầy đủ mỗi tính năng bằng API web; (c) không hỗ trợ web, chỉ ghi chú.
- Có muốn thêm CI chạy `flutter test --platform chrome` cho nhóm đã xác nhận (nhắc: owner đang hoãn CI, mục này chỉ là đề xuất sau).

## Acceptance criteria

- [ ] Chạy lại toàn bộ suite Chrome để có số đỏ chính thức, rồi bảng phân loại có kết luận từng nhóm kèm bằng chứng (lệnh, log).
- [ ] Không còn test đỏ không giải thích trên Chrome: mỗi test đỏ hoặc được sửa, hoặc có tag/skip kèm lý do cụ thể.
- [ ] Mọi thay đổi code kit có test chạy cả VM lẫn Chrome và không đổi hành vi native (so sánh bằng test VM cũ).
- [ ] Tài liệu nói rõ phần nào chạy trên web, không claim quá mức bằng chứng.
- [ ] Audit >9/10; device smoke chỉ khi đổi hành vi native (Pixel 7 Pro, không simulator).

## Kết quả thực hiện

- Phân loại / kết luận:
- Audit / điểm:
- Tests:
- Commit/push:
