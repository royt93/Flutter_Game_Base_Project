---
id: IDEA-35
title: "[Killer] Data-driven tutorial/onboarding authoring — mở rộng TutorialSequence để nhận JSON thay vì hardcode"
type: idea
priority: exclusive (độ tin cậy trung bình — xem ghi chú)
effort: M
source: Claude (claude --dangerously-skip-permissions, agent độc lập, brainstorm new/killer feature)
---

## Vị trí
Mở rộng — `lib/presentation/widgets/common/tutorial_sequence.dart`, `spotlight_overlay.dart`, `lib/core/remote_config_service.dart`.

## Hiện trạng
`TutorialSequence`/`TutorialStep` đã tồn tại nhưng hoàn toàn imperative — 1 `List<TutorialStep>` cố định với `GlobalKey`, message, thứ tự hardcode ngay trong code màn hình gọi nó. 1 studio muốn A/B-test copy/thứ tự onboarding, hoặc để game designer (không phải engineer) chỉnh flow tutorial, phải build lại app cho mỗi lần đổi câu chữ.

## Vì sao cần / Hậu quả
Đây là điểm khác biệt lớn so với 1 template Flutter chung chung — không template nào khác hỗ trợ sẵn tutorial authoring, càng không có sẵn seam remote-config để cắm vào ngay.

## Đề xuất
Mở rộng `TutorialSequenceController.start` để nhận thêm 1 danh sách bước dạng JSON (id → tên key widget đích, message, title, nhãn nút) đối chiếu với 1 `Map<String, GlobalKey>` registry do caller cung cấp, load trực tiếp từ `RemoteConfigService.getString('onboarding_flow_v1')`; log mỗi bước shown/dismissed qua `AnalyticsProvider` để phân tích funnel drop-off. Không thêm logic render mới — chỉ là 1 định dạng dữ liệu trên nền `TutorialSequence`/`SpotlightOverlay` đã có.

## Acceptance criteria
- [ ] TutorialSequenceController.start chấp nhận cả List<TutorialStep> hiện có LẪN JSON step list mới, không phá API cũ.
- [ ] JSON step tham chiếu đúng GlobalKey qua tên key trong registry do caller cung cấp.
- [ ] Mỗi bước log đúng sự kiện shown/dismissed qua AnalyticsProvider.
- [ ] Test: load JSON step list hợp lệ chạy đúng tutorial; JSON tham chiếu key không tồn tại trong registry xử lý an toàn (không crash, có thể skip bước đó); log analytics đúng số lần/đúng tên sự kiện.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-35-data-driven-tutorial-authoring.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng hay, dựa trên hạ tầng đã có sẵn (TutorialSequence + RemoteConfigService + AnalyticsProvider), nhưng effort M vì cần thiết kế định dạng JSON cẩn thận để không phá vỡ API imperative hiện có.
