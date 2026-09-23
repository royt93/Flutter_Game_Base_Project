---
id: FEAT-87
title: "LeaderboardSyncSeam — seam đồng bộ LocalScoreboardService lên backend thật (Play Games/Game Center/server riêng)"
type: feature
priority: P1
effort: M
source: "Fork nội bộ + claude (độc lập xác nhận cùng gap qua 2 góc nhìn), đối chiếu lib/core/local_scoreboard_service.dart"
---

## Vị trí
File mới `lib/core/leaderboard_sync_seam.dart`, đối chiếu `lib/core/local_scoreboard_service.dart` (service hiện tại, chỉ on-device) và `lib/core/cloud_save_provider.dart` (pattern seam mirror).

## Hiện trạng
`LocalScoreboardService` chỉ lưu trữ on-device, deterministic tie-break — không có seam nào để đồng bộ điểm số lên Play Games Services/Game Center/server riêng. Kit đã có pattern seam chuẩn cho 6 tích hợp khác nhưng bảng xếp hạng (1 tính năng lõi của game thi đấu/social) lại thiếu.

## Vì sao cần / Hậu quả
Game thật nào cũng cần bước "leaderboard online" sớm muộn — hiện tại consumer phải tự thiết kế toàn bộ interface đồng bộ (submit score, fetch top N, fetch quanh vị trí người chơi) từ đầu, không tận dụng được `LocalScoreboardService` đã có sẵn làm cache/fallback offline.

## Đề xuất
Thêm `LeaderboardSyncSeam` (interface trừu tượng): `Future<void> submitScore(String boardId, int score)`, `Future<List<ScoreEntry>> fetchTop(String boardId, {int limit})`, `Future<List<ScoreEntry>> fetchAroundPlayer(String boardId, {int radius})`. `LocalScoreboardService` đóng vai trò cache/fallback khi seam chưa đăng ký hoặc mất mạng (không thay thế, bổ sung).

## Acceptance criteria
- [ ] `LeaderboardSyncSeam` là interface trừu tượng thuần, không phụ thuộc SDK cụ thể.
- [x] `LocalScoreboardService` có thể hoạt động độc lập (không cần seam) như hiện tại — không breaking.
- [x] Có 1 helper/orchestrator tuỳ chọn nối 2 bên: submit lên cả local (ngay) và seam (async, best-effort), fetch ưu tiên seam nhưng fallback local khi mất mạng.
- [x] Export trong `lib/roy_casual_kit.dart`, cập nhật `tool/api_snapshot.json`.
- [x] Demo trong `example/` dùng 1 fake adapter test-only.
- [x] Test unit cho interface + fake adapter + fallback logic.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/FEAT-87-leaderboard-sync-seam.md` này trước khi làm. Đọc toàn bộ `lib/core/local_scoreboard_service.dart` và `lib/core/cloud_save_provider.dart` (pattern seam + CloudSaveProvider.syncWith tham khảo cách nối local/remote) trước khi tạo file mới. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`, `dart run tool/api_compatibility.dart check` pass.
4. Smoke test trên device thật khuyến khích (demo với fake adapter, verify fallback offline hoạt động đúng khi tắt mạng) không bắt buộc nếu widget test đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — 2 nguồn độc lập (Fork nội bộ, claude) cùng phát hiện gap này qua 2 góc nhìn khác nhau (fork: so sánh service coverage; claude: so sánh với 6 seam đã có). Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

Trước khi implement: quét `doc/task/done/*.md` bằng
`grep -lE "Từ chối, không làm"` (bài học rút ra ngay từ FEAT-86 trước đó
trong cùng phiên) — không có task nào từ chối leaderboard sync, an toàn để
làm. Đọc `lib/core/local_scoreboard_service.dart` (service on-device hiện
tại) và `lib/core/cloud_save_provider.dart` (pattern seam mirror) trước khi
viết file mới.

**Implement**: `lib/core/leaderboard_sync_seam.dart` — `ScoreEntry` (raw
`int` score, khác `LeaderboardEntry` ở `leaderboard_list.dart` vốn là type
hiển thị UI với score đã format string), `LeaderboardSyncSeam` (interface
trừu tượng thuần, `submitScore`/`fetchTop`/`fetchAroundPlayer`, `.maybe`
null-safe accessor, không `Noop*` default — đúng convention `PurchaseSeam`),
và `LeaderboardSyncCoordinator` (helper/orchestrator theo đúng đề xuất:
`submitScore` ghi local ngay + forward best-effort lên seam nuốt lỗi;
`fetchTop`/`fetchAroundPlayer` thử seam trước, seam throw hoặc chưa đăng ký
thì fallback về `LocalScoreboardService`, parse ngược `fmtNum`-formatted
score về `int` bằng cách strip non-digit — an toàn vì `fmtNum` chỉ thêm dấu
phân cách hàng nghìn, không bao giờ có phần thập phân).

`LocalScoreboardService` giữ nguyên 100% (0 dòng diff) — chứng minh trực
tiếp bằng test "hoạt động bình thường khi không có seam nào đăng ký".

**TDD**: viết `lib/core/leaderboard_sync_seam.dart` + 11 test unit trong
`test/core/leaderboard_sync_seam_test.dart` (maybe null/registered,
submitScore luôn ghi local, forward best-effort lên seam, seam lỗi không
mất bản ghi local, fetchTop đọc từ seam khi thành công, fallback local khi
seam throw, fallback local khi không có seam, fetchAroundPlayer fallback).
Xác nhận fail đúng lỗi biên dịch (`Method not found`) khi tạm di chuyển file
lib ra ngoài, rồi khôi phục — 11/11 pass. Thêm demo tile "LeaderboardSyncSeam
(fake adapter) — submit + fetchTop" vào `example/lib/screens/
cookbook_screen.dart` (fake `_FakeLeaderboardSyncSeam` cục bộ trong file,
cùng convention `_RecordingAnalyticsProvider` sẵn có — không dùng chung
`plugin_adapter_conformance_suite.dart` vì file đó có doc comment cố ý loại
trừ "ads"/bộ 5 seam cụ thể, không phải nơi chứa mọi fake). Tái sử dụng
instance `LocalScoreboardService` CHUNG với `WidgetShowcaseScreen` đã đăng
ký (`.maybe ?? Get.put`), không tạo instance riêng — cùng lý do
`_performanceTier` (ENH-80). Widget test mới trong
`example/test/cookbook_screen_more_test.dart` xác nhận fail (tile không tồn
tại) trước khi thêm code, pass sau khi thêm. Phát hiện 1 lỗi thiết kế test
tự viết (expect nhầm `top=CookbookPlayer:777` thay vì `top=remote_player:777`
— fake adapter's `submitScore(boardId, score)` không nhận `playerLabel`
(giống backend thật tự biết người chơi đang đăng nhập), nên record dưới
label cố định; sửa lại assertion, giữ nguyên code — đúng bug test, không
phải bug code).

**Kết quả**: `flutter analyze` sạch ở root và `example/`. `flutter test
--exclude-tags slow` root: 2113 test, 20 fail — khớp baseline ~19-21 golden
image macOS-only đã biết (không có fail mới liên quan thay đổi này). 1 lần
chạy riêng lẻ ghi nhận thêm `energy_service_test.dart`'s "BUG-52:
grantInfiniteLives cộng dồn..." fail do đua thời gian thật (`_realMs` là
getter, evaluate SAU khi `grantInfiniteLives` đã chạy — chênh vài ms) —
không liên quan `leaderboard_sync_seam.dart`/`local_scoreboard_service.dart`
(0 diff), test này tồn tại từ trước (commit `3b2b8d8`, phiên trước). `flutter
test --exclude-tags slow` ở `example/`: 134/134 pass. `dart run
tool/api_compatibility.dart check`: `additive` → chạy `snapshot` → lại
`unchanged`.

**Không làm** (khuyến khích, không bắt buộc): smoke test device thật — không
có SDK leaderboard thật để test qua kênh, và widget test (fake adapter +
fallback offline giả lập qua throw) đã chứng minh đủ hành vi theo đúng điều
kiện task tự nêu ("không bắt buộc nếu widget test đủ chứng minh"). Trừ 0.5
điểm vì lý do này.
