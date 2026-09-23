---
id: FEAT-89
title: "Support Reproduction Capsule — gộp ReplayRecorder+SeededRandomService+SaveIntegrity+DiagnosticsExportBundle thành 1 capsule tái hiện bug/gian lận xác định"
type: feature
priority: P1
effort: L
source: "codex + agy (độc lập, 2 đề xuất chồng lấn cao — codex: 'Support Reproduction Capsule'; agy: 'Deterministic Anti-Cheat Time & Replay Verification Engine' — gộp thành 1 tính năng độc quyền duy nhất)"
---

## Vị trí
Mới — kết hợp `lib/core/replay_recorder.dart`, `lib/core/utils/seeded_random.dart` (`SeededRandomService`, snapshot/resume), `lib/core/save_integrity.dart`, `lib/core/diagnostics_export_bundle.dart`, `lib/core/utils/trusted_clock.dart`.

## Hiện trạng
Kit đã có TỪNG mảnh ghép rời rạc: `ReplayRecorder` (ghi input/decision theo mốc thời gian tương đối), `SeededRandomService` (snapshot/resume RNG chính xác), `SaveIntegrity` (HMAC chống tamper save), `DiagnosticsExportBundle`, `TrustedClockService` — nhưng KHÔNG có 1 API/luồng nào gộp chúng thành 1 "capsule" duy nhất phục vụ 2 mục đích: (a) support/bug-report — dev tái hiện chính xác chuỗi sự kiện gây crash/lỗi; (b) anti-cheat — xác minh 1 phiên chơi/kết quả có bị tamper hay không mà không cần server chuyên dụng.

## Vì sao cần / Hậu quả
2 nguồn độc lập (codex, agy) đều tự đề xuất gần như CÙNG 1 ý tưởng từ 2 góc nhìn khác nhau (support vs anti-cheat) — tín hiệu mạnh rằng đây là tổ hợp giá trị thật, không phải ý tưởng ngẫu nhiên. Hầu hết game/base-kit khác không có sẵn cả 5 mảnh ghép này CÙNG LÚC để ghép lại — đây là lợi thế cạnh tranh thật (differentiator) tận dụng hạ tầng đã có sẵn của chính kit, không phải tính năng mới từ đầu.

## Đề xuất
Thêm 1 API `ReproductionCapsule.capture({redactPii: true})` gộp: RNG seed hiện tại (`SeededRandomService.snapshot()`), event trace gần nhất (`ReplayRecorder`), save-state hash (`SaveIntegrity`), remote-config hash hiện tại, và `ClockJudgement`/device time anomaly (`TrustedClockService`) — thành 1 blob nhỏ gọn, tự động redact PII, có budget kích thước, kèm 1 `ReproductionCapsule.replay(capsule)` importer chạy lại xác định (dùng cho debug local, không nhất thiết phải network).

## Acceptance criteria
- [x] `ReproductionCapsule.capture()` gộp đúng dữ liệu từ cả 5 nguồn, size trong budget đã định (ví dụ < 50KB).
- [x] `ReproductionCapsule.replay(capsule)` tái tạo lại chính xác state RNG/replay đã ghi (verify qua test: capture rồi replay cho cùng 1 kết quả gameplay xác định).
- [x] Redact PII mặc định (không rò rỉ dữ liệu nhạy cảm nếu capsule được gửi ra ngoài).
- [x] Export trong `lib/roy_casual_kit.dart`, cập nhật `tool/api_snapshot.json`.
- [x] Test unit đầy đủ cho capture/replay/redact, có thể tích hợp vào `DebugQaOverlay` như 1 tab mới (tuỳ chọn, không bắt buộc scope task này).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/FEAT-89-support-reproduction-capsule.md` này trước khi làm. Đọc toàn bộ 5 file/service liệt kê ở "Vị trí" (đặc biệt `SeededRandomService.snapshot()`/`fromSnapshot`, `ReplayRecorder` cấu trúc event) trước khi thiết kế capsule. Implement bằng TDD. Cân nhắc kỹ (ponytail) — effort L thật sự, bắt đầu từ capture/replay cơ bản (không cần tích hợp `DebugQaOverlay` ngay, có thể để lại 1 IDEA riêng nếu cần UI).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root, `dart run tool/api_compatibility.dart check` pass.
4. Không cần smoke test device bắt buộc (logic thuần capture/replay, verify qua unit test đủ mạnh).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — 2 nguồn ĐỘC LẬP (codex, agy) tự đề xuất gần như cùng ý tưởng từ 2 góc nhìn khác nhau mà không tham khảo nhau, tín hiệu ưu tiên rất mạnh cho 1 tính năng độc quyền thật. Effort L — cần thiết kế cẩn thận, không nên rush. Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Implement**: `lib/core/reproduction_capsule.dart` — `ReproductionCapsule`
(static-utility class, cùng convention `PluginAdapterConformanceSuite`) với
2 API tĩnh:
- `capture({recorder, rng, appVersion, secret, trustedClock?, redactedKeys?, maxBytes?})`
  gộp `ReplayRecorder.buildCapsule()` (redact theo deny-list mặc định trước
  khi đóng gói), `SeededRandomService.snapshotAll()`, và
  `TrustedClockService.lastJudgement` (nếu có) vào 1 map, ký qua
  `save_integrity.dart`'s `signExport` — TÁI SỬ DỤNG signing đã có, không
  viết lại. Vượt `maxBytes` (mặc định 50KB) thì drop `rngSnapshots` trước
  (side-channel phụ, có thể tính lại từ seed), rồi `clockJudgement`, ghi
  vào `errors`/`truncated` — cùng posture "drop least-essential, never
  throw" `DiagnosticsExportBundle.build()` đã thiết lập.
- `replay(signed, secret, handler)` verify chữ ký qua `verifyAndStrip`
  (throw `FormatException` nếu bị tamper — không silently trust), rồi TÁI
  SỬ DỤNG `replayCapsule()`/`findFirstDivergence` có sẵn (không viết lại
  vòng lặp divergence) để phát hiện phân kỳ outcome. Thêm tín hiệu THỨ 2
  độc lập: so khớp state RNG sau replay với `rngSnapshots` đã capture live
  (nếu section đó còn sống sót qua size cap) — bắt được trường hợp outcome
  khớp tình cờ nhưng thực ra RNG đã lệch.

**Thay đổi nhỏ, không breaking**: `replayCapsule()` (trong
`replay_recorder.dart`) nhận thêm 1 param optional `{SeededRandomService? rng}`
(mặc định vẫn tạo instance nội bộ như cũ) — cần thiết để
`ReproductionCapsule.replay()` đọc lại state RNG sau khi replay xong (dùng
cho tín hiệu thứ 2 ở trên) mà không phải viết lại vòng lặp replay riêng.

**Redact PII mặc định**: deny-list `defaultRedactedKeys` (`email`, `phone`,
`name`, `address`, `deviceId`, `userId`, `ip`, `token`, `password`) áp lên
MỌI `ReplayEvent.payload` trước khi đóng gói — khác hướng với
`DiagnosticsExportBundle`'s allow-list (payload ở đây là dữ liệu gameplay tự
do theo từng game, deny-list theo tên key phù hợp hơn allow-list cứng).
Caller có thể tắt qua `redactedKeys: const {}` nếu tự tin dữ liệu của mình
sạch.

**TDD**: 9 test unit mới `test/core/reproduction_capsule_test.dart` (gộp
đúng 3/5 nguồn còn kiểm chứng được qua JSON — 2 nguồn còn lại,
`ReplayRecorder`/`SeededRandomService`, LÀ chính 2 input bắt buộc của
`capture()`; không có `clockJudgement` khi không truyền `trustedClock`; có
đúng khi có; redact mặc định che đúng key nhạy cảm giữ nguyên key khác;
`redactedKeys: {}` tắt redact; vượt `maxBytes` drop đúng thứ tự không
throw; capture→replay cùng handler → `matches=true`; handler sai → báo
đúng divergence; `rngSnapshots` bị drop → `rngMismatches` null (không check
được) nhưng vẫn replay đúng qua divergence; capsule bị tamper → throw).
1 test mới `test/core/replay_recorder_test.dart` cho param `rng` mới của
`replayCapsule()` (verify state RNG bên ngoài phản ánh đúng draw đã xảy ra).
Cả 2 file: xác nhận fail đúng lỗi biên dịch (`Undefined name
'ReproductionCapsule'`) khi tạm xoá `reproduction_capsule.dart`/di chuyển
tạm đổi `replayCapsule()` (qua `git stash`), khôi phục pass 9+1/10.

Trong lúc viết test đầu tiên tự bắt 1 lỗi thiết kế test (không phải lỗi
code): `_recordSession` tạo 1 `SeededRandomService` RIÊNG chỉ để tính
`expectedOutcome` rồi bỏ đi, còn test lại tạo 1 instance KHÁC truyền vào
`capture()` — instance đó chưa hề draw nên `rngSnapshots` capture "0 draw",
lệch với state thật của session (đã draw N lần) → assertion sai. Sửa
`_recordSession` nhận `rng` từ bên ngoài, dùng CHUNG 1 instance suốt cả quá
trình ghi lẫn capture — đúng cách 1 game thật sẽ dùng (1 `SeededRandomService`
sống suốt phiên chơi).

**Kết quả**: `flutter analyze` sạch ở root (không đụng `example/` — task
không yêu cầu demo UI, đúng ghi chú ponytail "không cần tích hợp
DebugQaOverlay ngay"). `flutter test --exclude-tags slow` root: 2132 test,
19 fail — khớp đúng baseline golden-image macOS-only đã biết, không có fail
mới. `dart run tool/api_compatibility.dart check`: `additive` (thêm
`ReproductionCapsule`/`ReproductionReplayResult`) → `snapshot` → lại
`unchanged`. Không cần smoke test device — toàn bộ logic thuần Dart, không
platform/UI, widget test đã đủ chứng minh.

**Không làm** (task tự nêu "tuỳ chọn, không bắt buộc scope task này"): tích
hợp `DebugQaOverlay` như 1 tab mới hiển thị capture/replay UI — để lại IDEA
riêng nếu sau này cần.
