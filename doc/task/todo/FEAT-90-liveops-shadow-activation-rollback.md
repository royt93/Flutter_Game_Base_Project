---
id: FEAT-90
title: "LiveOps shadow activation — kích hoạt remote-config event/feature mới có auto-rollback khi vi phạm guardrail kinh tế"
type: feature
priority: P1
effort: L
source: "codex (độc lập)"
---

## Vị trí
Mới — dựa trên `lib/core/remote_config_service.dart`, `lib/core/remote_kill_switch_controller.dart`, `lib/core/season_event_service.dart`, `lib/core/economy_wallet.dart`.

## Hiện trạng
Kit đã có remote config + kill-switch riêng lẻ, nhưng không có cơ chế "bật thử 1 tính năng/event mới trên 1 tỷ lệ nhỏ người chơi, tự động giám sát các chỉ số kinh tế cốt lõi, và TỰ ĐỘNG rollback nếu vượt ngưỡng guardrail" — hiện tại mọi rollback đều phải người vận hành tự phát hiện và bấm kill-switch thủ công.

## Vì sao cần / Hậu quả
Live-ops game thật thường gặp sự cố kinh tế (bug cấu hình mới làm currency lạm phát/giảm phát bất thường) — phát hiện thủ công thường chậm, gây thiệt hại trước khi ai đó nhận ra và tắt tính năng.

## Đề xuất
Thêm `ShadowActivationController`: nhận 1 định nghĩa "guardrail" (ví dụ biên độ cho phép của tốc độ earn/spend trung bình), theo dõi telemetry cục bộ (qua `SdkEventSchemaRegistry` nếu đã có) trong lúc 1 feature/event mới bật cho 1 cohort nhỏ, tự động gọi `RemoteKillSwitchController` nếu vượt ngưỡng — không cần chờ người vận hành.

## Acceptance criteria
- [ ] API định nghĩa guardrail (ngưỡng min/max cho 1 metric theo dõi được).
- [ ] Vi phạm guardrail tự động kích hoạt kill-switch đúng feature liên quan, không ảnh hưởng feature khác.
- [ ] Test verify: giả lập metric vượt ngưỡng → auto-rollback đúng feature, log rõ lý do.
- [ ] Không tự động rollback khi metric trong ngưỡng cho phép.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/FEAT-90-liveops-shadow-activation-rollback.md` này trước khi làm. Đọc toàn bộ `lib/core/remote_kill_switch_controller.dart`, `lib/core/remote_config_service.dart`, `lib/core/sdk_event_schema_registry.dart` trước khi thiết kế. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root, `dart run tool/api_compatibility.dart check` pass.
4. Không cần smoke test device bắt buộc (logic thuần theo dõi guardrail, verify qua unit test).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — 1 nguồn (codex), ý tưởng hợp lý dựa trên hạ tầng thật đã có (`RemoteKillSwitchController`), nhưng chưa có prototype/thiết kế chi tiết cho "guardrail" — cần bàn kỹ scope trước khi implement full effort L. Không trùng task nào trong `doc/task/done/`.
