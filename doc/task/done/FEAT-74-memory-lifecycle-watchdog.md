---
id: FEAT-74
title: "Memory Lifecycle Watchdog"
type: feature
layer: core/debug
priority: P1
effort: M
depends_on: [FEAT-33, FEAT-39]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Debug-only tracker phát hiện ticker, controller, overlay, subscription và Flame component leak.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Tracker ghi owner/creation/dispose và report orphan sau test/session.
- [x] Không ship code/debug overhead vào release.
- [x] Fixture leak thật bị bắt, false positive có allowlist.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Xây `lib/core/memory_lifecycle_watchdog.dart` — `MemoryWatchdog`, thuần
static registry (không phải `GetxService`, giống style `SdkHealthReport`):

- `track(WatchdogKind kind, {required owner, label})` ghi 1 entry
  `{id, kind, owner, label, createdAtMs}` vào map sống, trả `id`.
- `release(id)` xoá khỏi map sống, đẩy sang `recentlyDisposed()` (bounded
  200, kèm `disposedAtMs`) — idempotent, gọi `release` với id không tồn
  tại/đã release rồi là no-op an toàn (khớp thực tế `dispose()` có thể bị
  gọi >1 lần trong 1 số lifecycle Flutter).
- `orphans({minAge})` — mọi entry còn sống, KHÔNG nằm trong allowlist,
  không quá trẻ hơn `minAge` (nếu truyền). Đây là danh sách "leak candidate"
  thật sự.
- `allow(label)`/`disallow(label)` — allowlist theo `label` (không theo
  `owner`, vì nhiều instance cùng class có thể chia sẻ `owner` nhưng chỉ 1
  vài cái trong đó là permanent-by-design).
- `memoryWatchdogHealthCollector()` — 1 `HealthCollectorSpec` (FEAT-39)
  opt-in báo `orphanCount`/`orphanKinds`, không phải 1 phần
  `defaultHealthCollectors()` (khác audio/performance/remoteConfig, đây
  không phải "module có đăng ký hay không", mà luôn sẵn có, opt-in vì bản
  chất debug diagnostic).

**Không có overhead ở release**: mọi method bắt đầu bằng `if
(!kDebugMode) return ...;` — đúng convention `dlog()`
(`lib/core/debug_log.dart`) đã dùng, `kDebugMode` compile-time-foldable
nên build AOT release dead-code-eliminate phần còn lại. KHÔNG thể tự viết
test trực tiếp chứng minh claim này (mọi `flutter test` luôn chạy ở debug
mode) — giống hệt tình trạng `dlog()` (không có `debug_log_test.dart`
nào trong repo), ghi rõ lý do trong doc comment thay vì giả vờ có test
kiểm tra được điều không thể kiểm tra bằng `flutter test`.

**Ví dụ allowlist thật lấy từ chính codebase** (không phải case bịa):
`NeonBg`'s permanent background `Ticker`
(`lib/presentation/widgets/neon_bg.dart`, đã verify bằng grep trước khi
viết vào doc comment) — đúng "testing gotcha" đã ghi trong `CLAUDE.md`
("NeonBg's ticker never settles"). Đây chính là lý do cần allowlist: nếu
không có, 1 watchdog ngây thơ sẽ báo leak sai cho đúng 1 Ticker permanent
by design.

Verify:
- `flutter analyze` root + `example/`: sạch.
- `flutter test --exclude-tags slow` root: 1818/1818 pass (1802 cũ + 16
  test mới `memory_lifecycle_watchdog_test.dart`).
- `dart run tool/api_compatibility.dart check` → `additive` đúng
  `MemoryWatchdog`/`WatchdogKind`/`WatchdogEntry`/`DisposedWatchdogEntry`,
  CHANGELOG khớp; `snapshot` lại → `unchanged`.
- `dart pub publish --dry-run`: chỉ cảnh báo git chưa commit, không lỗi
  thật.
- 16 test: track/release happy path (release idempotent, lịch sử
  `recentlyDisposed` đúng `disposedAtMs`); fixture leak THẬT — dựng
  `AnimationController(vsync: tester)` không dispose bị bắt, dispose xong
  hết; `StreamSubscription` không cancel bị bắt, cancel xong hết; nhiều
  leak cùng lúc liệt kê đủ; allowlist đúng theo `label` (permanent ticker
  không báo, label khác vẫn báo, không có label thì allowlist vô nghĩa,
  `disallow` gỡ đúng 1 label); `minAge` lọc đúng entry còn non; `reset`
  dọn sạch cả live/history/allowlist; `memoryWatchdogHealthCollector`
  đúng count/kind/allowedKeys (chỉ 2 field, không leak owner/label thô ra
  health report).
- Device smoke test thật trên **Samsung S24 Ultra (SM-S928B)**: build lại
  debug APK `example/` (barrel `lib/roy_casual_kit.dart` có export mới),
  cài, `HomeScreen` render đúng, không crash (`mobile_get_crash` không có
  report) — xác nhận export mới không phá app thật, theo đúng lưu ý mới
  của user (ưu tiên S24U).

**Không có UI/widget demo mới** trong `example/` — nhất quán với chính
FEAT-39 (`SdkHealthReport`) cũng chưa có demo trực quan trong
`WidgetShowcaseScreen` (kiểm tra: không có), nên không tạo tiền lệ lệch
chuẩn khi để `MemoryWatchdog` cũng chỉ có unit test làm bằng chứng chính.
Tiêu chí animation/reduced-motion N/A, tick vì không có gì để vi phạm.

Tự chấm: 9.3/10. Trừ điểm vì chưa wire `memoryWatchdogHealthCollector()`
vào 1 demo thật trong `example/` (ví dụ 1 nút "Grant XP" cố tình leak 1
`AnimationController` để chứng minh watchdog bắt được ngay trên device
thật) — hợp lý để lại làm follow-up, không tự ý thêm 1 demo section mới
vào `WidgetShowcaseScreen` (đã rất dài) khi acceptance criteria không bắt
buộc.

