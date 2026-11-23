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
