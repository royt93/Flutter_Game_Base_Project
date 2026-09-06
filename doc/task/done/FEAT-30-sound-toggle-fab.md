---
id: FEAT-30
title: SoundToggleFab — nút nổi bật/tắt nhạc nhanh
type: feature
priority: P2
effort: S
source: user pick (vòng audit cuối cùng, chốt)
---

## Vì sao cần
`AudioManager.muted` (`RxBool`) hiện chỉ có 1 nơi thao tác là `SettingsScreen`
— màn hình gameplay muốn có nút tắt tiếng nhanh phải tự viết lại `Obx` +
`AudioManager.to.toggleMute()` từ đầu.

## Đề xuất phạm vi
`SoundToggleFab`: widget nhỏ tự `Obx` lắng nghe `AudioManager.maybe?.muted`
(dùng đúng accessor null-safe đã có, không require audio phải sẵn sàng), tự
đổi icon loa/loa gạch chéo, tự gọi `toggleMute()` khi tap. Nếu
`AudioManager.maybe == null` (chưa đăng ký) → ẩn hẳn widget thay vì lỗi.

## Yêu cầu test
- **Unit test**: không áp dụng (thuần UI binding).
- **Widget test**: dựng khi `AudioManager` đã đăng ký, tap → verify `muted` đổi giá trị và icon đổi theo; dựng khi `AudioManager` KHÔNG đăng ký → widget không throw, không hiển thị gì (hoặc hiển thị disabled tuỳ thiết kế, miễn không crash).
- **Integration test**: demo trong `example/integration_test/`, tap thật trên thiết bị, verify nhạc nền thật sự dừng/phát lại theo trạng thái.

## Demo
Thêm `SoundToggleFab` vào `WidgetShowcaseScreen` (hoặc `HomeScreen`) cạnh các widget khác.

## Acceptance criteria
- [ ] Không throw khi `AudioManager` chưa đăng ký (test widget trong môi trường không audio, giống pattern test hiện có của package).
- [ ] Đủ 3 loại test + demo.
