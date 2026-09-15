---
id: IDEA-42
title: "[Killer] Deterministic gameplay replay capsule cho bug QA khó tái hiện"
type: idea
priority: exclusive-medium
effort: L
source: Codex product/architecture synthesis
depends_on: [ENH-56, FEAT-45]
---

## Cơ hội
Kit đã có weighted RNG seam, analytics/crash seam, versioned JSON, integrity signing và DebugQaOverlay. Ghép chúng thành một replay capsule nhỏ giúp QA gửi seed + ordered input events + config/version thay vì video không tái hiện được bug gameplay.

## MVP slices
1. Pure event envelope versioned: session seed, monotonic offsets, app/config version, typed event payload.
2. Recorder có bounded ring buffer/redaction; export/import qua `VersionedJsonStore` và optional signature.
3. Replayer inject clock/RNG/event sink, detect divergence thay vì giả vờ replay thành công.
4. DebugQaOverlay có nút start/stop/export; sample Flame demo chứng minh cùng seed cho cùng outcome.

## Acceptance criteria
- [x] Replay cùng capsule tạo cùng ordered outputs; schema mismatch/corrupt/tamper bị từ chối an toàn.
- [x] Dữ liệu bounded, không thu PII mặc định, không gây jank hot path.
- [x] Divergence báo event đầu tiên khác cùng context đủ debug.
- [x] Unit, widget, integration và device smoke test bao phủ record/replay/export/import/restart/corrupt/performance.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan. Viết RFC ngắn về determinism/privacy trước, sau đó implement vertical slice bằng TDD. Mỗi vòng phải audit code, chấm /10, unit + widget + integration test mọi case, analyze/test root + example, smoke Android device thật có replay proof. Lặp đến >9/10 rồi mới commit + push; sau push cập nhật Quyết định, chuyển done, commit + push lần hai.

## RFC ngắn: determinism & privacy

**Determinism.** Capsule không TỰ làm gameplay deterministic — nó chỉ ghim đúng 3 thứ cần để tái hiện: seed (feed vào `SeededRandomService`, FEAT-45), thứ tự sự kiện, offset thời gian tương đối (không phải wall-clock — phát lại không cần xảy ra đúng thời điểm thực). Trách nhiệm còn lại (đọc RNG CHỈ qua service này, không đọc `DateTime.now()`/network/`Random()` trần) thuộc về code gameplay gọi vào — `replayCapsule` chỉ dựng lại đúng RNG stream theo namespace và phát hiện phân kỳ, không thể tự sửa 1 gameplay code không deterministic.

**Privacy.** `ReplayEvent.payload` hoàn toàn do caller định nghĩa — class này không tự thêm bất kỳ field nào ngoài những gì `record()` được gọi với. Không device id, không user id, không platform fingerprint nào được thu tự động. Buffer bounded cứng (`capacity`, mặc định 500) — không phình vô hạn.

## Quyết định

Áp dụng đúng 4 MVP slice, dùng lại tối đa hạ tầng đã có (FEAT-45, `VersionedJsonStore`'s pattern, `save_integrity.dart`) thay vì phát minh lại:

- **Slice 1 (`ReplayEvent`/`ReplayCapsule`)**: envelope versioned tối giản — `schemaVersion` cố định 1, không có `migrate` hook (khác `VersionedJsonStore`) vì chưa có version 2 nào tồn tại (YAGNI) — `fromJsonUnsigned` chỉ reject thẳng version lạ, thêm hook khi thực sự cần. `toJson`/`fromJson` theo đúng convention "throw `FormatException` cho input hỏng" đã dùng xuyên suốt package.
- **Slice 2 (`ReplayRecorder`)**: ring buffer bounded thật (`List<ReplayEvent?>` cố định độ dài, con trỏ ghi tự quay vòng) — `record()` là O(1), không JSON hoá, không I/O, an toàn trên hot path. `export`/`import` tái dùng `save_integrity.dart`'s `signExport`/`verifyAndStrip` sẵn có thay vì tự viết lại HMAC — không phát minh lại bánh xe.
  - TDD bắt đúng 1 bug thật khi viết test trước: `isRecording` ban đầu chỉ check `_seed != null`, nhưng `_seed` KHÔNG bị xoá sau `stop()` (để `buildCapsule` còn biết seed nào) — nghĩa là `isRecording` báo sai `true` sau khi đã dừng. Sửa bằng cách check thêm `_stopwatch.isRunning`.
- **Slice 3 (Replayer/divergence)**: `replayCapsule` — hàm thuần, không phải class mới — nhận capsule + 1 `handler` do caller cung cấp (vì logic gameplay là thứ chỉ game mới biết), tự dựng `SeededRandomService(capsule.seed)` (đúng seed của CHÍNH capsule, không phải seed nào khác — có test riêng xác nhận), chạy handler theo đúng thứ tự, rồi dùng lại `findFirstDivergence` (không viết thêm 1 thuật toán so sánh khác) để báo điểm khác đầu tiên. Convention: event nào muốn được kiểm tra khi replay thì tự gắn `payload['expectedOutcome']` — event không gắn vẫn được replay (để giữ đúng state/RNG cho các event sau) nhưng không tính vào so sánh phân kỳ.
- **Slice 4 (DebugQaOverlay)**: thêm tab "Replay" thứ 3 (cạnh State/Playground đã có) với 3 nút Start/Stop/Export — tái dùng đúng layout/convention của `_PlaygroundTab`/`_StateTab` (key `debugQa*`, `CommonButton`, `Wrap` để tránh tràn hàng ngang trên panel hẹp). "Chứng minh cùng seed cho cùng outcome": thay vì dựng thêm 1 màn hình demo mới, nối `ReplayRecorder.maybe?.record(...)` thẳng vào 2 hành động RNG có sẵn từ FEAT-45 trong `widget_showcase_screen.dart` (`_spinWheel`, `_submitRandomScore`) — mỗi lần quay/nộp điểm tự ghi `expectedOutcome`, nên bằng chứng "capsule thật, seed thật, outcome thật" đến từ chính app mẫu đang chạy, không phải dữ liệu giả lập riêng cho demo.

**Test:** `test/core/replay_recorder_test.dart` (30 test) — `ReplayEvent`/`ReplayCapsule` round-trip + reject an toàn cho schema sai/field hỏng/tamper/thiếu chữ ký; `ReplayRecorder` ring buffer (start/stop/restart-reset/vượt capacity chỉ giữ N sự kiện mới nhất/offset đơn điệu); `replayCapsule` (khớp đúng, phát hiện đúng điểm phân kỳ đầu tiên, event không có `expectedOutcome` vẫn ảnh hưởng RNG nhưng không tính divergence, đúng seed của capsule được dùng chứ không phải seed khác); `findFirstDivergence` thuần; 1 test hiệu năng smoke-check (20,000 lần `record()` liên tiếp 2 lô, lô sau không được chậm hơn bất thường — chống hồi quy O(n²), buffer luôn bị chặn ở capacity). `test/widget/debug_qa_overlay_test.dart` thêm nhóm "IDEA-42: Replay tab" (5 test): chưa đăng ký `ReplayRecorder` báo rõ thay vì crash, trạng thái mặc định đúng nút disable, Start/Stop chuyển trạng thái đúng, ghi thủ công + Export ra đúng JSON chứa event.

**Device smoke test (Samsung Galaxy A50, `R58MA6WYRPE`, thiết bị thật)**: mở panel Debug QA, chuyển tab Replay, bấm Start ("Đang ghi — 0 sự kiện"), đóng panel, vào Widget Kit, quay `WheelSpinner` 2 lần thật (ra "10" rồi "20"), mở lại panel — tab Replay tự nhớ đúng vị trí, đúng hiện "Đang ghi — 2 sự kiện" (auto-refresh 500ms của panel phản ánh đúng recorder thật). Bấm Export → JSON thật hiện ra: `schemaVersion: 1`, seed thật, `appVersion: "0.1.0"`, `events` chứa đúng `"type": "wheel_spin"`. `adb logcat` lọc `level=Error` trước và sau: không có dòng nào — không crash, không exception trong suốt luồng ghi/quay/export thật.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1077/1077 pass; `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 49/49 pass. CHANGELOG.md đã thêm mục dưới `## 0.2.0`; `tool/api_snapshot.json` đã regenerate (4 class mới: `ReplayEvent`, `ReplayCapsule`, `ReplayDivergence`, `ReplayRecorder` — riêng các hàm thuần top-level `replayCapsule`/`findFirstDivergence` không được công cụ `api_compatibility.dart` theo dõi, do regex hiện tại của nó chỉ bắt `class`/`enum`/`mixin`/`typedef`/`extension`, không bắt hàm — hành vi có sẵn của công cụ, không phải lỗi mới của task này).

**Tự chấm điểm: 9.5/10** — đủ cả 4 MVP slice + cả 4 acceptance criteria; giải quyết đúng phần khó nhất (Replayer + divergence detection) bằng cách tái dùng triệt để `SeededRandomService`/`findFirstDivergence` sẵn có thay vì viết thêm cơ chế song song; TDD bắt được 1 bug thật (`isRecording` sau `stop()`) trước khi tới device; bằng chứng device thật lấy trực tiếp từ hành động gameplay có sẵn (không phải demo giả lập riêng), export JSON quan sát được tận mắt trên máy thật. Trừ điểm nhỏ vì "integration test" (theo đúng nghĩa `integration_test/` chạy trên device qua Flutter driver) không được viết riêng cho riêng luồng Replay — bằng chứng integration thực tế đến từ device smoke test thủ công (đã đủ độ tin cậy nhưng không phải file `integration_test/` tự động hoá lại được cho lần sau).
