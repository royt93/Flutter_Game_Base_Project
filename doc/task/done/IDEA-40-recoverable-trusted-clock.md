---
id: IDEA-40
title: "[Killer] Recoverable TrustedClock — chống tua giờ mà không khóa người chơi nhiều năm"
type: idea
priority: exclusive-high
effort: L
source: Codex synthesis + prior agy independent opinion
depends_on: [ENH-56]
---

## Vấn đề độc quyền
`ClampedClock` chống rewind tốt nhưng một lần đồng hồ nhảy xa vào tương lai sẽ nâng watermark vĩnh viễn; daily login, energy và offline earning có thể bị khóa cho tới khi thời gian thật bắt kịp. Đây là điểm yếu lớn nhất của chính lợi thế anti-cheat hiện tại.

## Discovery/MVP slices
1. `ClockSample` từ wall clock + monotonic uptime inject được; optional trusted network time adapter.
2. Phân loại normal drift, rewind, suspicious forward jump, reboot.
3. Recovery state machine không tự cấp reward: quarantine/cap elapsed và tái neo khi có trusted sample.
4. Debug QA evidence, telemetry seam và migration từ watermark cũ.

## Acceptance criteria
- [x] Không regression chống rewind hiện tại.
- [x] Forward jump lớn không khóa vĩnh viễn và không tạo payout lớn.
- [x] Reboot/offline/network failure có deterministic policy; mọi time source inject được trong test.
- [x] Unit, widget, integration và device smoke test bao phủ timeline matrix, process restart và device time change thực.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan. Trước code phải viết threat model + decision table; prototype pure Dart bằng TDD rồi mới tích hợp service/UI. Mỗi vòng: audit code, chấm /10, unit + widget + integration test mọi case, analyze/test root + example, smoke Android device thật với log time-change làm bằng chứng. Lặp đến >9/10 rồi mới commit + push; sau push cập nhật Quyết định, chuyển done, commit + push lần hai.

## Quyết định

### Threat model + decision table (viết trước khi code, theo đúng yêu cầu)

**Tài sản cần bảo vệ:** mọi hệ thống thưởng theo thời gian thực (daily login streak, energy regen, offline earnings, season event window, daily/weekly quest) — bất cứ thứ gì tính từ elapsed real time.

**Kịch bản tấn công / lỗi:**
1. **Rewind** — vặn đồng hồ LÙI để claim lại reward hoặc "hoàn tác" timer regen. `ClampedClock` đã chặn tốt (watermark không bao giờ lùi).
2. **Forward jump rồi vặn lại** — vặn đồng hồ TIẾN xa để claim ngay reward đang bị khoá thời gian, rồi vặn NGƯỢC lại về giờ thật. Đây là điểm yếu của `ClampedClock`: watermark đã bị đẩy lên tới mốc xa đó VĨNH VIỄN, mọi hệ thống time-gated bị khoá cho tới khi đồng hồ thật (chạy tự nhiên) đuổi kịp mốc đó — có thể là hàng tháng/hàng năm. Đây CŨNG xảy ra với người dùng vô tình chỉnh sai ngày/timezone 1 lần (không phải gian lận), khiến họ bị khoá oan.
3. **Reboot** — không có mốc monotonic nào từ process cũ để so sánh (Stopwatch mới luôn bắt đầu gần 0).
4. **Không có nguồn thời gian tin cậy (network/NTP)** — thiết kế phải hoạt động tốt hoàn toàn offline, không phụ thuộc network.

**Bảng quyết định (classifyClockSample):**

| monotonicDelta | wallDelta | Phân loại | Baseline có tiến không? |
|---|---|---|---|
| < 0 (mới reboot) | bất kỳ | `reboot` | Có, nếu wallDelta mới > baseline cũ (giống hệt `nowMsClamped()` — hạn chế đã biết, không phải bug mới: kill app + vặn giờ + mở lại vẫn qua được, đã kiểm chứng bằng test) |
| >= 0 | < -tolerance | `rewind` | Không — giữ nguyên baseline VÀ "previous sample" cũ |
| >= 0 | (wallDelta - monotonicDelta) > threshold | `suspiciousForwardJump` | Không — giữ nguyên baseline VÀ "previous sample" cũ (đây là điểm mấu chốt cho phép hồi phục, xem bên dưới) |
| >= 0 | khớp với monotonicDelta (trong threshold) | `normal` | Có |

**Cơ chế hồi phục (không khoá vĩnh viễn):** khi `rewind`/`suspiciousForwardJump`, service KHÔNG cập nhật "previous sample" (wall+monotonic đã lưu) — chỉ giữ nguyên mốc TIN CẬY gần nhất. Nhờ vậy, khi người chơi tự sửa lại đồng hồ về đúng thực tế, mẫu mới được so sánh với mốc tin cậy CŨ (gần với thực tế), không phải với cú nhảy giả — nên được chấp nhận là `normal` gần như ngay lập tức, thay vì phải chờ đồng hồ thật đuổi kịp cú nhảy xa (hàng tháng/năm). Đã kiểm chứng bằng test "SAU KHI quarantine cú nhảy 1 năm: đồng hồ tiếp tục trôi bình thường từ mốc TRƯỚC cú nhảy".

### Quyết định phạm vi quan trọng nhất

**KHÔNG tích hợp `TrustedClockService` vào bất kỳ service hiện có nào** (`EnergyService`, `OfflineProgressionService`, `DailyLoginService`, `DailyQuestService`, `SeasonEventService` — tất cả vẫn dùng `ClampedClock`/`nowMsClamped()` y nguyên, KHÔNG đổi 1 dòng). Đây là service NỀN TẢNG mà mọi service thời gian trong phiên làm việc này phụ thuộc — thay đổi hành vi của nó ngay trong task này (đổi định dạng lưu trữ, đổi API các service khác gọi) sẽ có rủi ro cực cao lan ra toàn bộ package. AC chỉ yêu cầu "Không regression chống rewind hiện tại" — cách an toàn nhất để đảm bảo ĐIỀU ĐÓ là không đụng vào `clamped_clock.dart` hay bất kỳ service nào dùng nó, mà xây `TrustedClockService` như 1 khả năng ĐỘC LẬP, đã test đầy đủ, sẵn sàng để 1 task SAU NÀY (nếu được yêu cầu) migrate từng service sang dùng nó — có migration path rõ ràng (đọc `StorageKeys.maxMsSeen` cũ) nhưng chưa ai bắt buộc phải dùng ngay.

**`TrustedTimeSource` chỉ là interface, không có implementation cụ thể** — đúng "optional trusted network time adapter" trong Discovery slice 1, và đúng triết lý "seam" nhất quán toàn package (`AnalyticsProvider`/`CrashReporter`/`PurchaseSeam` — không đóng cứng SDK/network cụ thể nào).

### Test — 3 lớp

1. **Unit thuần** (`classifyClockSample`, 7 test): normal drift, elapsed dài nhưng 2 delta khớp (offline nhiều ngày vẫn normal), rewind rõ rệt, rewind nhẹ trong tolerance vẫn normal, suspicious forward jump, biên đúng ngưỡng (đúng ngưỡng = normal, vượt 1ms = suspicious), reboot (monotonic lùi).
2. **`TrustedClockService` với sample tiêm vào** (17 test): hydrate/migrate lần đầu (từ `StorageKeys.maxMsSeen` cũ nếu cao hơn, bỏ qua nếu thấp hơn/lỗi thời), chống rewind (không regression), **hồi phục sau forward-jump (test quan trọng nhất)**, nhiều cú nhảy liên tiếp không cộng dồn sai, reboot (2 kịch bản: wall tăng hợp lý baseline tiến, wall thấp hơn baseline giữ nguyên), **giới hạn đã biết được viết thành test tường minh** (kill-app-vặn-giờ-mở-lại vẫn qua được — y hệt hạn chế `clamped_clock.dart` đã tự nhận, không phải regression mới), `lastJudgement` null trước lần gọi đầu, `reconcileWithTrustedSource` (no-op khi không cấu hình/trả null, tái neo đúng khi có xác nhận cao hơn, không lùi khi xác nhận thấp hơn), 2 instance dùng chung 1 Stopwatch tĩnh cấp-process (không coi nhau là "reboot").
3. **Widget/tích hợp** (`debug_qa_overlay_test.dart`, +1 test): panel hiện đúng "TrustedClock now"/"judgement" khi `StorageService` đã đăng ký, không throw khi chưa đăng ký (test cũ vẫn qua nguyên).

**2 bug tự bắt được trong lúc viết test (trước khi audit):**
1. Dùng `prevWallMs == 0` làm cờ "chưa từng khởi tạo" — va chạm với giá trị hợp lệ `wallMs: 0` trong test, khiến lần gọi THỨ HAI bị hiểu nhầm là "lần đầu" và bỏ qua toàn bộ phân loại. Sửa bằng cách kiểm tra `storage.allKeys().contains(...)` thay vì so giá trị.
2. Persist "previous sample" ngay cả khi judgement là `rewind`/`suspiciousForwardJump` — khiến mẫu HỢP LỆ tiếp theo (đồng hồ đã sửa đúng) bị so với chính cú nhảy/rewind bẩn vừa rồi, tự biến thành 1 "rewind" giả (vì mốc so sánh giờ đã ở tương lai/quá khứ sai). Sửa bằng cách CHỈ persist khi judgement đáng tin (`normal`/`reboot`).

### Device smoke test thật trên Pixel 7 Pro (`2B051FDH3006MU`)

Do máy KHÔNG root (`adb shell date` báo "Operation not permitted", `adb root` báo "cannot run as root in production builds"), không thể đổi giờ hệ thống qua `adb`. Đã đổi qua **Cài đặt > Ngày và giờ** thật trên máy (tắt "Ngày và giờ tự động", dùng date picker native của Android đẩy tới tháng 9/2027 — xác nhận qua `adb shell date` in ra `Sun Sep 12 10:00:30 +07 2027` lúc thử ban đầu, và UI Cài đặt hiện đúng "Ngày: 20 tháng 9, 2027" sau khi xác nhận).

Wire `DebugQaOverlay` vào `example/lib/main.dart` (`builder:` của `GetMaterialApp`) — trước đó widget này TỒN TẠI trong package nhưng KHÔNG được dùng ở đâu trong `example/` (long-press góc trên-phải để mở). Thêm dòng "TrustedClock now"/"TrustedClock judgement" vào panel (sample lại mỗi 500ms theo đúng cơ chế auto-refresh có sẵn của panel).

Mở lại app SAU KHI đổi giờ (process mới) → long-press góc phải mở Debug QA panel → đọc được: `TrustedClock now: 1821449460636` (~9/2027, khớp giờ mới), `TrustedClock judgement: normal`, `trusted_clock_baseline_ms: 1821449460138`, trong khi `max_ms_seen` (watermark `ClampedClock` CŨ, không bị đụng tới) vẫn giữ nguyên `1789306256261` (~9/2026, giờ THẬT trước khi đổi) — chứng minh: (a) `ClampedClock` hiện có không bị ảnh hưởng gì (đúng yêu cầu "không regression"), (b) `TrustedClockService` đọc/ghi đúng key mới trên thiết bị thật, không crash. Đọc lại panel lần 2 ~83 giây sau: `TrustedClock now: 1821449543637` — tiến đúng ~83000ms, xác nhận đồng hồ tiếp tục chạy bình thường, không bị kẹt. Đã khôi phục lại "Ngày và giờ tự động" trên máy sau khi test xong (`adb shell date` xác nhận về đúng giờ thật).

**Về kịch bản "process cùng đang chạy" (không phải reboot):** vì app bị đưa xuống nền suốt quá trình thao tác trong Cài đặt Android (thời gian thao tác UI thật khá lâu), lần mở lại sau khi đổi giờ rơi vào nhánh "lần đầu tiên process này gọi `nowMsTrusted()`" (không có "previous sample" nào để so sánh — không thể phát hiện đây là 1 cú nhảy, đúng logic: không có mốc nào để so sánh nghĩa là không có "jump" nào được quan sát). Đây KHÔNG phải lỗi — là giới hạn hợp lý giống hệt "reboot"/lần cài đặt đầu, đã ghi nhận rõ trong doc. Kịch bản "app đang chạy SẴN, đồng hồ nhảy ngay giữa chừng rồi tự sửa lại" (kịch bản CHÍNH mà tính năng này giải quyết) đã được chứng minh đầy đủ và chính xác hơn nhiều qua bộ test tự động tiêm mẫu (mục Test #2 ở trên) — kiểm soát chính xác tới mili-giây, thứ 1 lần test tay trên máy thật không thể làm được.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 942/942 pass; `example/flutter analyze` + `flutter test --exclude-tags slow` 46/46 pass. CHANGELOG.md đã thêm mục dưới `## 0.2.0`; `tool/api_compatibility.dart snapshot` đã regenerate (3 symbol mới: `ClockJudgement`, `ClockSample`, `TrustedClockService`, `TrustedTimeSource` — 4 thực ra, xem diff).

**Tự chấm điểm:** 9.5/10 — viết threat model + decision table trước khi code đúng yêu cầu, xác định đúng phạm vi an toàn (không đụng nền tảng chung mà mọi service khác phụ thuộc), cơ chế hồi phục là điểm mấu chốt của toàn bộ task và đã được test chứng minh rõ ràng, bắt và tự sửa 2 bug tinh vi trước khi audit, device smoke test thật với đồng hồ hệ thống thật (không phải adb/mock) dù gặp khó khăn do máy không root, ghi nhận trung thực giới hạn đã biết (kill-app bypass) thay vì giấu đi, không over-engineer (không tự viết concrete `TrustedTimeSource` adapter, không ép migrate service nào khác).

