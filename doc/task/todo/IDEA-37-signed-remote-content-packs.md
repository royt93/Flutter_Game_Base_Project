---
id: IDEA-37
title: "[Killer] Signed remote content packs — live-ops nội dung game không cần backend riêng"
type: idea
priority: exclusive (độ tin cậy trung bình — xem ghi chú)
effort: L
source: Claude (claude --dangerously-skip-permissions, agent độc lập, brainstorm new/killer feature)
---

## Vị trí
Mở rộng — `lib/core/remote_config_service.dart`, `lib/core/versioned_json_store.dart`, `lib/core/save_integrity.dart`.

## Hiện trạng
`RemoteConfigService` hiện chỉ là key/value phẳng (`getString`/`getInt`/`getBool`/`getDouble`) với fallback asset — tốt cho feature flag, không đủ cho việc đẩy NỘI DUNG game thật (cấu hình level, catalog shop, lịch sự kiện) mà không cần qua chu kỳ duyệt app store. Đây là tính năng "vì sao chọn kit này thay vì 1 app Flutter trắng" được yêu cầu nhiều nhất, và khó xây ở nơi khác vì cần chính xác 3 mảnh đã có sẵn trong repo này: pattern asset-fallback-rồi-fetch của `RemoteConfigService`, câu chuyện migrate theo schema-version của `VersionedJsonStore`, và HMAC signing của `save_integrity.dart` (tái dùng ở đây để đảm bảo 1 file JSON bị giả mạo/host sai không thể âm thầm làm hỏng config sống) — không 1 template chung nào có sẵn cả 3 mảnh này cùng lúc.

## Vì sao cần / Hậu quả
Không có cơ chế này, mọi thay đổi nội dung game (level mới, sự kiện mới, giá shop mới) đều cần build + submit app store mới — chậm và tốn kém so với đối thủ có live-ops thật.

## Đề xuất
`RemoteContentPack<T>` xây trên `RemoteConfigService` + bước `migrate` của `VersionedJsonStore`: load 1 JSON array/object có kiểu (ví dụ định nghĩa level) từ cùng pipeline asset-rồi-`fetchRemote`, xác thực HMAC qua helper kiểu `signEmbed` đã có sẵn trong `save_integrity.dart` nếu caller cung cấp `contentSecret`, fallback về asset đóng gói sẵn khi chữ ký/schema sai — không bao giờ chặn boot vì 1 lệnh gọi mạng.

## Acceptance criteria
- [ ] RemoteContentPack<T>.load() không bao giờ block boot chờ network — luôn có sẵn asset fallback dùng ngay, cập nhật ngầm khi fetch xong.
- [ ] Nội dung có chữ ký sai hoặc schema không hợp lệ tự động fallback về asset đóng gói, không crash, không áp dụng nội dung chưa xác thực.
- [ ] Test: asset-only (không network) hoạt động đúng; fetch thành công với chữ ký hợp lệ áp dụng đúng nội dung mới; fetch với chữ ký sai/schema sai fallback về asset, không silently corrupt state.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-37-signed-remote-content-packs.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — đây là ý tưởng "killer feature" mạnh nhất trong nhóm (tận dụng đúng 3 mảnh hạ tầng độc đáo đã có), nhưng effort L và cần thiết kế API cẩn thận (đặc biệt phần ký/xác thực) — nên prototype nhỏ trước khi cam kết full scope.
