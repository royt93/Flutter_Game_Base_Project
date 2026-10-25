---
id: POST-RELEASE-0.6.3-MONITORING
title: "Theo dõi sau phát hành roy_casual_kit 0.6.3"
type: monitoring
layer: release/consumer-feedback
priority: P2
effort: XS
source: "user-selected post-release sequence 2026-10-25"
---

## Trạng thái phát hành

- pub.dev hosted package `roy_casual_kit 0.6.3` đã resolve thành công trong consumer sample.
- Consumer sample bên ngoài repo: `flutter analyze` sạch; 3/3 tests pass.
- Git tag `v0.6.3`, GitHub Release và upload pub.dev đã hoàn tất.
- GitHub CI cho release commit `435bc39` pass cả `quality-gate`, `analyze-test`, `consumer-smoke`.
- Repo `main` sạch tại commit release; không có open GitHub issues trong lần rà gần nhất.

## Mục tiêu

Quan sát lỗi/regression và feedback consumer thật sau 0.6.3. Không mở feature speculative hoặc intake 0.6.4 nếu chưa có tín hiệu cụ thể.

## Checklist khi có lần rà tiếp theo

- [ ] Kiểm tra pub.dev vẫn liệt kê 0.6.3 là hosted release mới nhất.
- [ ] Rà GitHub Issues/consumer feedback kể từ release; ghi link/id và affected flow nếu có.
- [ ] Kiểm tra CI của `main` và các commit hậu release nếu có.
- [ ] Tách confirmed regression khỏi nhu cầu feature mới; không suy diễn từ lượt tải hoặc khoảng im lặng.
- [ ] Nếu không có issue/feedback/regression cụ thể, ghi “no new signal”, giữ backlog và dừng.
- [ ] Nếu có tín hiệu, ghi reproduction, impact, expected behavior và acceptance criteria; đối chiếu service/widget/task đã có trước khi tạo intake 0.6.4.

## Ràng buộc

- Chỉ code trên `main`; không tạo branch/worktree.
- Không tạo tag hoặc publish version tiếp theo khi chưa có duyệt rõ.
- Mọi feature/bug implementation mới cần được người dùng duyệt scope trước khi chuyển sang `inprogress`.
- Không suy đoán backend delivery, payout, analytics transport hoặc replay authenticity từ UI/callback evidence.

## Prompt loop monitoring

Đọc file này, `doc/task/RELEASE-0.6.3-INTAKE-CHECKLIST.md` và trạng thái hiện tại của main/pub.dev/GitHub. Chỉ đọc dữ liệu hậu phát hành; không sửa code, version, tag, release hay publish. Ghi evidence theo URL/issue/CI id. Nếu không có signal cụ thể thì kết luận no-op và không mở task 0.6.4. Nếu có signal, đề xuất task nhỏ nhất ở `todo/` với reproduction và acceptance criteria; chờ người dùng duyệt trước khi đổi trạng thái hoặc code.

## Quyết định

Tạo checklist hậu phát hành theo lựa chọn “làm tuần tự 1 > 3 > 2”. Không mở intake 0.6.4 vì lần rà này chưa thấy issue/feedback mới. Chưa commit/push file checklist này.
