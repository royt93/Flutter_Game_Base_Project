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
- [ ] `LocalScoreboardService` có thể hoạt động độc lập (không cần seam) như hiện tại — không breaking.
- [ ] Có 1 helper/orchestrator tuỳ chọn nối 2 bên: submit lên cả local (ngay) và seam (async, best-effort), fetch ưu tiên seam nhưng fallback local khi mất mạng.
- [ ] Export trong `lib/roy_casual_kit.dart`, cập nhật `tool/api_snapshot.json`.
- [ ] Demo trong `example/` dùng 1 fake adapter test-only.
- [ ] Test unit cho interface + fake adapter + fallback logic.

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
