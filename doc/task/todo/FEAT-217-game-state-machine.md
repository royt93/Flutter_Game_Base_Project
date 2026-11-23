---
id: FEAT-217
title: "Máy trạng thái nhỏ (FSM) cho AI kẻ địch và flow màn chơi: cần ranh giới rõ với GameSessionController"
type: feature
layer: lib/core
priority: P4
effort: M
source: "Đề xuất của Claude 2026-11-23, owner chọn đưa vào backlog (đề xuất có rủi ro trùng, đã nêu)"
---

Kit chỉ có `GameSessionController` (phase của một phiên: loading/ready/playing/paused/won/lost). Không có FSM tổng quát (quét `lib`: không có StateMachine) cho AI kẻ địch, boss, tutorial.

## Rủi ro đã nêu khi đề xuất

Dễ trùng `GameSessionController`. Phải chốt ranh giới trước khi code: `GameSessionController` giữ nguyên là nguồn sự thật cho PHASE phiên; FSM mới là kiểu chung cho trạng thái CỤC BỘ của một thực thể. Không để FSM thay thế hay bọc nó.

## Phạm vi đề xuất

- `StateMachine<S, E>` thuần Dart: bảng chuyển (S, E) -> S, hook `onEnter/onExit`, điều kiện chuyển (guard), trạng thái không hợp lệ ném `StateError` rõ ràng ở biên cấu hình (kiểm lúc dựng, không ở runtime), có thể `fromJson` cho save.
- Test: chuyển hợp lệ/không hợp lệ, guard, thứ tự enter/exit, bảng thiếu trạng thái đích bị từ chối lúc dựng; mutation check.

## Câu hỏi mở

Có cần phân cấp (hierarchical) hay chỉ phẳng ở bản đầu. Đề xuất: phẳng.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Chốt API `StateMachine<S, E>` (chữ ký, lỗi, biên) trong "Kết quả thực hiện"; trả lời các "Câu hỏi mở" (nếu chưa có owner trả lời, dùng "Đề xuất" ghi trong task và nêu rõ).
- [ ] 2. Viết test TRƯỚC (đỏ) cho các trường hợp biên liệt kê trong Phạm vi, rồi viết cài đặt thuần Dart (không import Flutter).
- [ ] 3. Viết một đoạn "Ranh giới với GameSessionController" vào dartdoc: `GameSessionController` vẫn là nguồn sự thật phase phiên, FSM là trạng thái cục bộ của thực thể; không bọc, không thay thế.
- [ ] 4. Bảng chuyển kiểm lúc dựng: trạng thái đích thiếu bị từ chối ngay (không để lỗi lúc chạy); test thứ tự `onExit` -> chuyển -> `onEnter`, guard chặn chuyển.
- [ ] 5. Invariant constructor/tham số bằng `ArgumentError` (ENH-85); dữ liệu từ nguồn không tin cậy dùng `SdkResult`, không ném (BUG-112).
- [ ] 6. Mutation check: phá logic chính, test phải đỏ, rồi khôi phục (dùng python/Edit, không dùng sed trên macOS).
- [ ] 7. Export + `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 8. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển file sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Bảng chuyển sai bị từ chối lúc dựng.
- [ ] Không import hay sửa `GameSessionController`.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/utils test/core/game_session_controller_test.dart`
