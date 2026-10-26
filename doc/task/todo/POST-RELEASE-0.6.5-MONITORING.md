---
id: POST-RELEASE-0.6.5-MONITORING
title: "Theo dõi sau phát hành roy_casual_kit 0.6.5"
type: monitoring
layer: release/consumer-feedback
priority: P2
effort: XS
source: "user-selected post-release sequence 2026-10-26"
---

## Trạng thái phát hành

- pub.dev liệt kê `roy_casual_kit 0.6.5` là `latest` (đăng 2026-10-26T04:13Z). Phiên bản 0.6.4 chưa từng được publish lên pub.dev; pub.dev đi thẳng từ 0.6.3 lên 0.6.5.
- Git tag `v0.6.5` trỏ commit `7cfadce`; GitHub Release: https://github.com/royt93/Flutter_Game_Base_Project/releases/tag/v0.6.5
- GitHub CI: run 40265823288 trên `7cfadce`, run 40268097876 trên `d0dd9b8` và run 40269662059 trên `fa6908f` pass cả `quality-gate`, `analyze-test`, `consumer-smoke`. Run 40210322949 trên `4fb904c` có một lần `consumer-smoke` timeout emulator, pass khi rerun.
- Không có open GitHub issue tại lần rà này.
- Consumer sample ngoài repo (`/tmp/roy_consumer_065`, không phải path dependency): `roy_casual_kit: 0.6.5` resolve từ `https://pub.dev` (`source: hosted`, sha256 `029fa80c…1281`); `flutter analyze` sạch; 5/5 test pass (8 hướng `GameJoystick`, trả về neutral khi thả tay, hook `PlayableCharacter.onAttack` và kiểm tra tốc độ, `terrainColliderOverlapsRect` với tường mỏng, polygon collider không còn là `PolygonComponent`). Sample nằm trong `/tmp` nên không được lưu vào repo.

## Chưa kiểm chứng

- Bằng chứng thiết bị thật chỉ từ Pixel 7 Pro; TECNO KJ7 mất kết nối USB giữa chừng nên chưa có.
- Ghi chú 0.6.4 trong CHANGELOG (joystick trong `GameDemoScreen`) đã được 0.6.5 đính chính, nhưng 0.6.4 chưa có release GitHub riêng.

## Mục tiêu

Quan sát lỗi/regression và feedback consumer thật sau 0.6.5. Không mở feature speculative hoặc intake 0.6.6 nếu chưa có tín hiệu cụ thể.

## Checklist khi có lần rà tiếp theo

- [ ] Kiểm tra pub.dev vẫn liệt kê 0.6.5 là hosted release mới nhất.
- [x] Resolve `roy_casual_kit: 0.6.5` từ pub.dev trong consumer sample ngoài repo; chạy `flutter analyze` và test của sample (2026-10-26, xem Trạng thái phát hành).
- [ ] Rà GitHub Issues/consumer feedback kể từ release; ghi link/id và affected flow nếu có.
- [ ] Kiểm tra CI của `main` và các commit hậu release nếu có.
- [ ] Tách confirmed regression khỏi nhu cầu feature mới; không suy diễn từ lượt tải hoặc khoảng im lặng.
- [ ] Nếu không có issue/feedback/regression cụ thể, ghi “no new signal”, giữ backlog và dừng.
- [ ] Nếu có tín hiệu, ghi reproduction, impact, expected behavior và acceptance criteria; đối chiếu service/widget/task đã có trước khi tạo intake mới.

## Ràng buộc

- Chỉ code trên `main`; không tạo branch/worktree.
- Không tạo tag hoặc publish version tiếp theo khi chưa có duyệt rõ.
- Mọi feature/bug implementation mới cần được người dùng duyệt scope trước khi chuyển sang `inprogress`.
- Không suy đoán backend delivery, payout, analytics transport hoặc replay authenticity từ UI/callback evidence.

## Prompt loop monitoring

Đọc file này và trạng thái hiện tại của main/pub.dev/GitHub. Chỉ đọc dữ liệu hậu phát hành; không sửa code, version, tag, release hay publish. Ghi evidence theo URL/issue/CI id. Nếu không có signal cụ thể thì kết luận no-op và không mở task mới. Nếu có signal, đề xuất task nhỏ nhất ở `todo/` với reproduction và acceptance criteria; chờ người dùng duyệt trước khi đổi trạng thái hoặc code.

## Quyết định

Tạo hồ sơ theo dõi theo lựa chọn “1 rồi 2” của người dùng sau khi phát hành 0.6.5. Chưa có signal nào cho 0.6.6.
