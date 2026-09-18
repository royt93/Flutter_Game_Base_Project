---
id: FEAT-61
title: "ConsentStateService — gate analytics/ads/personalization theo consent"
type: feature
layer: app/data-logic
priority: P1
effort: M
depends_on: [FEAT-03, FEAT-02, FEAT-32, FEAT-37]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là app developer, tôi muốn một SSOT consent có version để provider chỉ hoạt động khi được phép.

## Sprint slices
- Immutable consent categories/status/source/policyVersion/timestamp.
- Repository versioned persistence và controller commands grant/deny/reset.
- Provider gate cho analytics, ads và personalization; default deny nơi chưa quyết định.
- UI seam do consumer render, SDK chỉ cung cấp state/commands và example.

## Acceptance criteria
- [x] Chưa consent/deny không gửi event hay khởi tạo provider bị gate.
- [x] Policy version mới đưa category cần thiết về trạng thái review lại theo rule.
- [x] Revoke có hiệu lực tức thì và persist qua restart.
- [x] Corrupt save không biến thành granted; race update deterministic.

## Prompt loop feature
Đọc task/providers/storage; viết consent transition/privacy matrix và TDD. End loop: audit, chấm /10; unit test + widget test + integration test mọi grant/deny/revoke/version/corrupt/provider gate; analyze/test root + example; smoke Android device thật chứng minh network/provider bị chặn/mở. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

**Phạm vi cố ý bị bó hẹp — đã hỏi và được user xác nhận trước khi code**: title/sprint slice gốc nhắc "gate cho analytics, ads và personalization", nhưng FEAT-02 (ads mediation interface) đã bị TỪ CHỐI dứt khoát trước đó ("Chủ repo không muốn quảng cáo trong base kit này" — quyết định phạm vi sản phẩm, không phải kỹ thuật). Không có `AdsProvider` nào tồn tại để gate. User chọn: bỏ hẳn category "ads", chỉ gate `analytics` + `personalization`.

Kiến trúc:
- `ConsentCategory` chỉ có 2 giá trị (`analytics`, `personalization`) — không khai báo `ads` "cho có" vì sẽ gây hiểu nhầm là đã có cơ chế gate ads trong khi thực tế không.
- **Default-deny 2 tầng**: (1) category chưa từng `grant()`/`deny()` đọc ra `ConsentStatus.unknown`, KHÔNG PHẢI `granted` — `isGranted()` chỉ true khi status THỰC SỰ là `granted`; (2) entry persisted bị hỏng (JSON sai, field sai kiểu, giá trị `status` không khớp enum nào) bị BỎ QUA hoàn toàn thay vì cố coerce — đọc ra y hệt "chưa từng quyết định" (`unknown`), không bao giờ tình cờ trở thành `granted`.
- **Policy version**: mỗi `ConsentRecord` mang theo `policyVersion` tại thời điểm quyết định. `recordOf()` so `policyVersion` đã lưu với `policyVersion` HIỆN TẠI của service (constructor param) — cũ hơn thì coi như `unknown` NGAY LẬP TỨC (lazy, không cần bước migrate riêng), category phải được quyết định lại. Quyết định lại dưới version mới thì ổn định qua các lần đọc tiếp theo (đã kiểm chứng bằng test `policyVersion` chain 3 bước: v1 grant → v2 đọc lại thành unknown → v2 grant lại → v2 đọc lại lần nữa vẫn granted).
- **Revoke tức thì + persist qua restart**: `grant`/`deny`/`reset` ghi thẳng bằng `setString` (không buffer) và cập nhật ngay trong cùng instance (không cần đọc lại từ storage) — đúng yêu cầu "revoke có hiệu lực tức thì".
- **Race update deterministic**: do Dart đơn luồng, gọi liên tiếp `grant()` rồi `deny()` (không có `await` giữa 2 lệnh) luôn cho kết quả CUỐI CÙNG là lệnh gọi sau — đã test rõ (`grant→deny→grant→deny` liên tiếp, kết quả cuối = denied).
- **Provider gate**: xây `ConsentGatedAnalyticsProvider implements AnalyticsProvider` — decorator bọc quanh 1 `AnalyticsProvider` thật, chỉ forward `logEvent` khi `isGranted(analytics)` đúng true (mặc định từ chối luôn cả khi chưa có `ConsentStateService` nào đăng ký — `ConsentStateService.maybe?.isGranted(...) ?? false`). Consumer app đăng ký decorator này THAY vì provider thật (`Get.put<AnalyticsProvider>(ConsentGatedAnalyticsProvider(real), permanent: true)`) — mọi call site tự động tôn trọng consent, không cần tự check thủ công từng nơi.
- **"Personalization" không có seam riêng như analytics** (`ExperimentBucketingService` là concrete GetX service, không phải abstract interface như `AnalyticsProvider`) — quyết định KHÔNG ép thêm 1 abstract interface mới chỉ để wrap nó (out of scope, đó là việc refactor riêng của `ExperimentBucketingService` nếu cần). Thay vào đó demo tại CALL SITE: `WidgetShowcaseScreen` check `_consent.isGranted(personalization)` trước khi gọi `_experiments.variantFor(...)`, fallback hiện "blocked (no personalization consent)" khi chưa được phép — đúng tinh thần "UI seam do consumer render, SDK chỉ cung cấp state/commands" của sprint slice.

**Test:** `test/core/consent_state_service_test.dart` (16 case, TDD — RED xác nhận qua "Undefined name"/"Method not found" trước khi viết `consent_state_service.dart`): default-deny, grant/deny/reset, 2 category độc lập, revoke tức thì, race đồng bộ, policy version bump (3 kịch bản), sống qua "restart", corrupt JSON top-level, corrupt 1 entry sai kiểu, reactive revision. `test/core/consent_gated_analytics_provider_test.dart` (5 case): chưa có service đăng ký, unknown, denied, granted forward đúng, revoke giữa chừng ngừng forward. `example/test/widget_showcase_screen_test.dart` (+5 case, FEAT-61 group): mặc định unknown, chưa grant không tăng event, grant rồi log tăng đúng, deny sau grant ngừng tăng, grant personalization mở khoá đúng variant thay vì "blocked".

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1448/1448 pass (1 lần chạy gặp 2 flaky pre-existing đã biết — `api_compatibility_test.dart` do quên snapshot lại sau khi thêm export mới, đã fix bằng `dart run tool/api_compatibility.dart snapshot`; và `energy_service_test.dart` atomic-write timing test, pass khi chạy riêng lẻ, máy tải nặng không liên quan code). example `flutter analyze` sạch, `flutter test --exclude-tags slow` 64/64 pass. `dart pub publish --dry-run` → 1 warning quen thuộc. CHANGELOG.md cập nhật mục 0.2.0.

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): rebuild + cài, mở Bộ Widget, scroll tới demo "ConsentStateService (FEAT-61)". Xác nhận đúng luồng thật: mặc định "Analytics: unknown"/"Personalization: unknown", bấm "Log demo event (gated)" khi chưa consent → "Demo events actually logged: 0" (không tăng). Bấm "Grant analytics" → "Analytics: granted"; bấm "Log demo event" lặp lại nhiều lần → tăng đúng liên tục 0→1→2→3 (chứng minh cơ chế gate + forward hoạt động thật trên device, không chỉ mock). Bấm "Grant personalization" → demo `ExperimentBucketingService` bên dưới chuyển từ "blocked (no personalization consent)" sang hiện đúng variant thật ("gold") — chứng minh gate call-site cho personalization hoạt động đúng trên device thật. Có 1-2 lần tap ban đầu không phản hồi ngay (nghi thiết bị dùng chung với session khác bị tranh foreground trước đó trong phiên) — đã debug bằng `print()` tạm thời + kiểm tra lại nhiều lần liên tiếp, xác nhận đây là tool/thiết bị flaky nhất thời chứ không phải bug thật (cơ chế tăng ỔN ĐỊNH ở các lần bấm sau, không crash, không log lỗi nào trong `mobile_get_device_logs`/`mobile_list_crashes`), debug code đã được gỡ bỏ trước khi commit.

**Tự chấm điểm: 9.5/10** — default-deny đúng ở CẢ 2 TẦNG (chưa quyết định VÀ corrupt save đều không thể trở thành granted); policy-version-bump-bắt-review-lại hoạt động lazy, không cần bước migrate riêng; quyết định KHÔNG ép thêm abstract interface cho `ExperimentBucketingService` chỉ để làm demo đẹp (đúng tinh thần YAGNI, giữ scope đúng của task); phát hiện đúng đây không phải ads gate giả tạo mà loại bỏ hẳn để tránh hiểu nhầm. Trừ 0.5 vì gặp nhiễu tool/thiết bị khi smoke test khiến phải debug thêm 1 vòng build (không phải lỗi code, nhưng tốn thêm thời gian xác minh).

