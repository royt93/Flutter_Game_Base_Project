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
- [x] API định nghĩa guardrail (ngưỡng min/max cho 1 metric theo dõi được).
- [x] Vi phạm guardrail tự động kích hoạt kill-switch đúng feature liên quan, không ảnh hưởng feature khác.
- [x] Test verify: giả lập metric vượt ngưỡng → auto-rollback đúng feature, log rõ lý do.
- [x] Không tự động rollback khi metric trong ngưỡng cho phép.

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

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Phát hiện quan trọng khi đọc `remote_kill_switch_controller.dart` trước
khi thiết kế** (đúng bước "đọc kỹ trước khi implement"): controller này
CHỈ đọc trạng thái kill từ `RemoteConfigService` — hoàn toàn không có API
ghi/tự kill từ phía client. Acceptance criteria yêu cầu "tự động kích hoạt
kill-switch" — nghĩa là `ShadowActivationController` phải THỰC SỰ gọi được
vào `RemoteKillSwitchController` để kill ngay lập tức, không đợi vòng poll
remote tiếp theo. Vì vậy bổ sung 2 method mới cho
`RemoteKillSwitchController` (thay đổi nhỏ, không breaking — thêm field
private mới + 2 method public mới):
- `forceKillLocally(featureId, {required reason})` — set 1 override cục bộ,
  ưu tiên CAO NHẤT trong `_resolve()` (đứng trước cả `remoteValid`) — đúng
  lý do tồn tại: phản ứng NHANH HƠN vòng poll remote tiếp theo.
- `clearLocalOverride(featureId)` — gỡ override, quay lại resolution order
  thường (remote/cached/asset).
- Thêm `KillSwitchSource.localOverride` vào enum hiện có (audit trail phân
  biệt rõ "tự client kill" với "ops kill qua remote").

**Implement**: `lib/core/shadow_activation_controller.dart` —
`GuardrailDefinition` (min/max cho 1 metric, `assert` bắt buộc có ít nhất 1
bound — guardrail không bound nào là vô nghĩa) và `ShadowActivationController`
(nhận `RemoteKillSwitchController` qua constructor, `registerGuardrail`/
`reportMetric`). Cố ý KHÔNG tự tính rolling-average/tích hợp
`SdkEventSchemaRegistry` — Đề xuất ghi "theo dõi telemetry cục bộ (qua
SdkEventSchemaRegistry NẾU ĐÃ CÓ)" tức tuỳ chọn, và acceptance criteria
thực tế chỉ yêu cầu 1 API ngưỡng + auto-rollback, không yêu cầu bộ máy
thống kê; `reportMetric` nhận value ĐÃ TÍNH SẴN (caller tự quyết định value
là gì — tức thời hay trung bình), giữ lớp này tối giản, tổng quát cho MỌI
guardrail-checkable metric thay vì hardcode logic "earn/spend rate" cụ thể.
Cũng KHÔNG làm cohort bucketing (rollout theo % người chơi) — không có
trong acceptance criteria, đã có sẵn `ExperimentBucketingService` cho việc
đó nếu cần sau.

**TDD**: 9 test unit mới `test/core/shadow_activation_controller_test.dart`
(trong ngưỡng không rollback; vượt max rollback đúng + reason có tên
guardrail/giá trị; dưới min rollback đúng; vi phạm 1 feature KHÔNG ảnh
hưởng feature khác; metricName không khớp không rollback; feature chưa
đăng ký guardrail không throw không rollback; nhiều guardrail cùng feature
chỉ cần 1 cái vi phạm; `GuardrailDefinition.violatedBy` đúng cho từng loại
bound riêng lẻ; thiếu cả 2 bound → assert). 4 test mới trong
`test/core/remote_kill_switch_controller_test.dart` cho
`forceKillLocally`/`clearLocalOverride` (kill ngay bất kể remote nói gì;
chỉ ảnh hưởng đúng featureId; clear quay lại resolution order thường; local
override ưu tiên hơn cả remote hợp lệ nói killed=true). Cả 2 file: xác
nhận fail đúng lỗi biên dịch khi tạm xoá `shadow_activation_controller.dart`
/ `git stash` `remote_kill_switch_controller.dart`, khôi phục pass 9+4/13.

**Kết quả**: `flutter analyze` sạch ở root. `flutter test --exclude-tags
slow` root: 2144 test, 20 fail — khớp đúng baseline golden-image macOS-only
đã biết, không có fail mới. `dart run tool/api_compatibility.dart check`:
`additive` (thêm `ShadowActivationController`/`GuardrailDefinition`) →
`snapshot` → lại `unchanged`. Không cần smoke test device (logic thuần,
task tự ghi rõ "Không cần smoke test device bắt buộc").
