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
- [ ] `ReproductionCapsule.capture()` gộp đúng dữ liệu từ cả 5 nguồn, size trong budget đã định (ví dụ < 50KB).
- [ ] `ReproductionCapsule.replay(capsule)` tái tạo lại chính xác state RNG/replay đã ghi (verify qua test: capture rồi replay cho cùng 1 kết quả gameplay xác định).
- [ ] Redact PII mặc định (không rò rỉ dữ liệu nhạy cảm nếu capsule được gửi ra ngoài).
- [ ] Export trong `lib/roy_casual_kit.dart`, cập nhật `tool/api_snapshot.json`.
- [ ] Test unit đầy đủ cho capture/replay/redact, có thể tích hợp vào `DebugQaOverlay` như 1 tab mới (tuỳ chọn, không bắt buộc scope task này).

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
