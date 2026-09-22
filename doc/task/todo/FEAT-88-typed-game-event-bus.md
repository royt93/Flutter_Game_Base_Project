---
id: FEAT-88
title: "Typed game-event bus nối Flame gameplay events với economy/progression/analytics — hiện phải tự nối tay từng chỗ"
type: feature
priority: P1
effort: L
source: "codex (độc lập)"
---

## Vị trí
Mới — cầu nối giữa `lib/presentation/game/roy_game.dart`/Flame `Component` events và các service nghiệp vụ (`EconomyWallet`, `PlayerProgressionService`, `AnalyticsProvider`, `AchievementService`).

## Hiện trạng
Kit có đầy đủ service nghiệp vụ (economy, progression, achievement) VÀ Flame integration (`RoyGame`), nhưng không có 1 lớp trung gian typed kết nối "sự kiện gameplay xảy ra trong Flame world" (ví dụ: entity bị tiêu diệt, level hoàn thành, combo đạt ngưỡng) với các service nghiệp vụ đó — mỗi consumer phải tự viết code nối tay từ Component callback sang service call, dễ quên 1 nhánh (ví dụ quên log achievement khi thêm 1 loại sự kiện mới).

## Vì sao cần / Hậu quả
Thiếu lớp trung gian này khiến việc "thêm 1 loại sự kiện gameplay mới cần cả economy VÀ progression VÀ achievement VÀ analytics đều biết" trở thành 4 chỗ sửa rời rạc, dễ sót — đúng loại lỗi tích hợp phổ biến nhất khi game phát triển thêm tính năng.

## Đề xuất
Thêm 1 `GameEventBus` nhẹ (không phụ thuộc GetX Rx bắt buộc — có thể chỉ là `StreamController<GameEvent>` broadcast), định nghĩa `GameEvent` là sealed/union type mở rộng được. Consumer game code bắn 1 event duy nhất (`bus.emit(EntityDefeated(...))`), các service nghiệp vụ tự đăng ký subscriber cho loại event chúng quan tâm — thêm 1 service subscriber mới không cần sửa code bắn event.

## Acceptance criteria
- [ ] `GameEventBus` typed, mở rộng được (thêm 1 loại `GameEvent` mới không cần sửa bus).
- [ ] Ít nhất 2 service nghiệp vụ (ví dụ `EconomyWallet`, `AchievementService`) có ví dụ subscriber thật trong `example/` minh hoạ cùng 1 event bắn ra kích hoạt cả 2 độc lập.
- [ ] Export trong `lib/roy_casual_kit.dart`, cập nhật `tool/api_snapshot.json`.
- [ ] Test unit cho bus (emit/subscribe/multiple subscriber, subscriber exception không làm crash bus/subscriber khác), widget/integration test cho demo trong `GameDemoScreen`.
- [ ] Không bắt buộc mọi game dùng kit phải dùng bus này (optional, không breaking `RoyGame` hiện tại).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/FEAT-88-typed-game-event-bus.md` này trước khi làm. Đọc toàn bộ `lib/presentation/game/roy_game.dart`, `example/lib/screens/game_demo_screen.dart`, và cách các service nghiệp vụ hiện có (`EconomyWallet`, `AchievementService`) expose API trước khi thiết kế bus. Implement bằng TDD. Cân nhắc kỹ (ponytail) — đây effort L, ưu tiên thiết kế tối giản (1 `StreamController` + sealed class) trước khi thêm bất kỳ cơ chế phức tạp hơn (priority, cancellation token...).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget/integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`, `dart run tool/api_compatibility.dart check` pass.
4. Smoke test trên device Android thật (mở `GameDemoScreen`, trigger sự kiện demo, verify cả 2 service subscriber phản ứng đúng, quan sát được qua UI/log).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — gap hợp lý dựa trên kiến trúc đã biết của kit (nhiều service nghiệp vụ độc lập + 1 Flame integration point tối giản), nhưng đây là 1 đề xuất thiết kế mới (không phải bug/gap cụ thể đã verify bằng code), cần bàn kỹ về mức độ cần thiết trước khi implement full effort L. Không trùng task nào trong `doc/task/done/`.
