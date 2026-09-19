---
id: FEAT-63
title: "AppSessionTracker — session id, install/session count và foreground duration"
type: feature
layer: app/core
priority: P2
effort: S
depends_on: [FEAT-33, FEAT-37, FEAT-61]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là product developer, tôi muốn metadata session nhất quán cho analytics/review/onboarding mà không để mỗi feature tự đếm.

## Sprint slices
- Immutable current session: random id, sequence, first install/open, start/resume times.
- Persist install/session counters nguyên tử; foreground duration dùng monotonic time.
- Lifecycle integration, analytics context provider và consent gate.
- Clock/process restart/corrupt state policy.

## Acceptance criteria
- [x] Một process session có một id; cold start tăng count đúng một lần.
- [x] Background không tính vào foreground duration; resume không tạo session mới ngoài policy.
- [x] Corrupt/negative counters recover không crash và không giảm sequence đã tin cậy.
- [x] Khi chưa analytics consent, tracker không tự gửi event/PII.

## Prompt loop feature
Đọc task/lifecycle/consent dependencies; TDD timeline/restart fixtures. End loop: audit, chấm /10; unit test + widget test + integration test mọi cold/warm start/background/corrupt/consent; analyze/test root + example; smoke Android device thật với force-stop/relaunch log. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Kiến trúc:
- **Một session/id per process**: `sessionId`/`sequence`/`installTimeMs` gộp vào 1 record bất biến `SessionInfo`, tạo lại đúng 1 lần trong CONSTRUCTOR (`_startNewSession()`) — GetxService sống suốt process nên "1 session/process" và "cold start tăng count đúng 1 lần" tự nhiên đúng, không cần cờ đánh dấu riêng.
- **Foreground duration dùng `Stopwatch`** (elapsed time thật), KHÔNG dùng `nowMsClamped()` — một phép đo THỜI LƯỢNG không quan tâm đồng hồ hệ thống có bị chỉnh hay không, chỉ cần thời gian trôi qua thật; `Stopwatch` cho đúng cái đó trực tiếp, khỏi tự tính hiệu số 2 mốc `nowMsClamped()` (dễ sai khi có anomaly). `Stopwatch` injectable qua `createStopwatch` (cùng seam convention `createTimer`) — test tự viết `_FakeStopwatch implements Stopwatch` để kiểm soát elapsed time tuyệt đối, không phụ thuộc thời gian thật khi chạy CI.
- **Policy resume**: nối tiếp CÙNG session nếu thời gian background < `sessionTimeout` (mặc định 30 phút, theo đúng quy ước phổ biến của SDK analytics mobile) — quá hạn thì tạo session MỚI (sessionId mới, sequence+1, foreground reset). Đây chính là "policy" acceptance criterion #2 nhắc tới.
- **Corrupt sequence**: đọc persisted sequence âm (hand-edited) → CLAMP về 0 trước khi +1 — không bao giờ lan truyền giá trị âm, cold start sau khi hỏng luôn báo lại từ sequence 1 trở lên, không throw.
- **Consent gate**: `analyticsContext()` chỉ trả context KHÔNG RỖNG khi `ConsentCategory.analytics` đã granted trên `ConsentStateService` (FEAT-61) — tracker KHÔNG tự gửi gì cả (không có concept "gửi" trong service này), chỉ cung cấp/CHE dữ liệu cho caller tự gắn vào event — đúng "widgets/services don't self-grant" convention đã dùng xuyên suốt kit.

**Bug thật phát hiện NGOÀI phạm vi task (user báo trực tiếp giữa lúc làm)**: `CommonButton`'s pill container có `padding: EdgeInsets.symmetric(vertical: NeonTheme.s8)` — THIẾU HẲN padding ngang, khiến label (đặc biệt label dài, ví dụ "Scenario: force (bấm để đổi)" ở demo FEAT-59) hiện sát/tràn ra mép nút bo tròn. Đây là bug ảnh hưởng TOÀN BỘ common widget kit (mọi `CommonButton` với label gần hết chiều rộng), không riêng gì task này — sửa bằng cách thêm `horizontal: NeonTheme.s16`. Kèm theo: phát hiện thêm 1 test cũ (`loading: true không làm đổi kích thước...`) dùng label quá dài ("Buy the whole shop") khiến `FittedBox` cần scale-down nhạy với padding mới, phá vỡ assertion không liên quan tới bản chất test — đổi sang label ngắn ("Buy") để test đúng cái nó MUỐN kiểm tra (loading không đổi size pill) mà không phụ thuộc hành vi scale-down. Golden test `shop_item_card_basic.png`/`shop_item_card_ribbon.png` (dùng `CommonButton` bên trong `ShopItemCard`) bị lệch pixel thật (1.14% diff) — đã `--update-goldens` sau khi verify ảnh mới đúng ý (có khoảng cách 2 bên, không dí sát viền).

**Test:** `test/core/app_session_tracker_test.dart` (14 case, TDD — RED xác nhận qua "Method not found" trước khi viết `app_session_tracker.dart`): cold start (sequence=1, installTimeMs set, sequence tăng đúng qua "restart", 2 sessionId khác nhau, sequence âm/hỏng clamp về 0), foreground duration (đếm ngay lúc start, dừng khi background, cộng dồn khi resume trong timeout), resume ngoài policy (background > sessionTimeout → session mới, reset foreground), consent gate (chưa có service/chưa consent → rỗng, granted → đúng field), tích hợp `RoyLifecycleCoordinator` (hook đăng ký đúng, nhận event thật qua `didChangeAppLifecycleState`). `test/widget/common/common_button_test.dart` (+1 case): pill có padding ngang thật (`Container.padding.horizontal > 0`), chống tái phát bug user vừa báo.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1522/1522 pass. example `flutter analyze` sạch, `flutter test --exclude-tags slow` 75/75 pass. `dart run tool/api_compatibility.dart check` → unchanged sau snapshot lại. `dart pub publish --dry-run` → 1 warning quen thuộc (kèm 2 golden PNG đã update trong danh sách file thay đổi). CHANGELOG.md cập nhật mục 0.2.0 (2 mục: fix padding + feature mới).

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): rebuild + cài, xác nhận TRỰC QUAN padding fix (mọi `CommonButton` giờ có khoảng cách rõ 2 bên, không dí sát viền bo tròn nữa). Scroll tới demo "AppSessionTracker (FEAT-63)": thấy đúng "Session #1", foreground đang đếm tăng dần theo thời gian thao tác thật, "Analytics context" hiện đúng JSON (vì consent analytics đã granted từ demo FEAT-61 trước đó, persisted qua storage). **Force-stop app thật** (`adb shell am force-stop`) rồi relaunch → demo hiện đúng **"Session #2"** với `sessionId` MỚI HẲN, foreground duration RESET về gần 0 và đếm lại từ đầu — đúng chính xác acceptance criterion #1 ("cold start tăng count đúng một lần") bằng bằng chứng force-stop/relaunch THẬT như prompt loop yêu cầu, không phải mock. Không crash (`mobile_list_crashes` rỗng).

**Tự chấm điểm: 9.5/10** — kiến trúc "1 session/process = tự nhiên đúng nhờ vòng đời GetxService" thay vì tự set cờ theo dõi; tái dùng đúng `RoyLifecycleCoordinator`/`ConsentStateService` đã có thay vì tự chế lifecycle/consent riêng; `Stopwatch` injectable đúng seam convention cho phép test foreground-duration hoàn toàn deterministic; NHÂN TIỆN sửa đúng 1 bug thật ảnh hưởng TOÀN BỘ widget kit mà user tự phát hiện giữa lúc làm task khác — phản ứng đúng: verify ngay bằng code, viết test chống tái phát, cập nhật golden, KHÔNG bỏ qua dù không nằm trong acceptance criteria gốc của task này. Trừ 0.5 vì bug padding lẽ ra nên được bắt sớm hơn (từ lúc build `CommonButton` ban đầu) qua 1 golden test tổng quát cho riêng `CommonButton` — hiện tại chỉ có golden cho `ShopItemCard` (gián tiếp chứa nó), chưa có golden trực tiếp cho chính `CommonButton`.
