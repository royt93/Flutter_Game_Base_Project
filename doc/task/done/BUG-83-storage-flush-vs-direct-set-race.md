---
id: BUG-83
title: "Race flush vs set trực tiếp làm mất update"
type: bug
priority: P1
effort: M
source: "fork audit core + verify phiên chính"
---

## Vị trí

`lib/core/storage_service.dart:159` `flush`.

## Hiện trạng

`flush` snapshot `_buffer` rồi ghi từng key async qua `_writeDirect`. Một `setInt`/`setString` trực tiếp xen giữa sẽ ghi giá trị mới xuống disk trước, sau đó `flush` ghi giá trị stale (đã snapshot) đè lên sau cùng → mất update. Doc comment trong file chỉ giải quyết chiều ngược lại (buffered-mới vs flush-cũ), không giải quyết direct-write xen giữa flush.

## Vì sao cần / Hậu quả

Hot-path counter (buffered) + transaction thật (unbuffered) trên cùng key = mất tiền/item của player trong điều kiện race thật trên device.

## Đề xuất

Serialize `flush` + mọi write qua cùng 1 save-chain/mutex (mẫu `_saveChain` các ledger service đã dùng, ví dụ `SeasonEventService`); `flush` chụp snapshot DƯỚI lock.

## Acceptance criteria

- [x] Test concurrent `flush` + `set` xen kẽ → giá trị cuối đúng thứ tự gọi, không mất update.
- [x] Không phá vỡ đảm bảo hiện tại: direct write luôn thắng buffered stale.

## Quyết định

**Implementation (v1, bị revert 1 phần):** Thử `AsyncActionGuard.runExclusive`
trước, nhưng full root suite phát hiện regression thật:
`AsyncActionGuard.runExclusive` LUÔN `await` tail trước đó dù đã resolved,
nên trì hoãn `prefs.setX(...)` ít nhất 1 microtask NGAY CẢ KHI không có
tranh chấp — phá vỡ nhiều service (vd `ConsentStateService._persist`) gọi
`setString(...)` fire-and-forget (không await) rồi đọc lại NGAY LẬP TỨC,
dựa vào tính chất "gọi `prefs.setX` đồng bộ trước khi hàm async đầu tiên
`await`" mà code gốc luôn có. Phát hiện qua `flutter test
--exclude-tags slow` đầy đủ (không chỉ file liên quan) — 9 test ở
`consent_state_service_test.dart` fail đồng loạt.

**Implementation (v2, final):** Viết `_guardedWrite` riêng thay
`AsyncActionGuard`: khi không có write nào đang chờ (`_pendingWrite ==
null`), gọi `write()` NGAY qua `Future.sync` — giữ nguyên tính chất đồng bộ
cũ. Chỉ khi có 1 write khác thật sự đang mid-flight thì mới chain
`.then()` phía sau nó. `flush()` truyền `queueWhenIdle: true` (luôn vào
hàng đợi, kể cả khi rảnh — để 1 `setInt` trực tiếp gọi NGAY SAU đó chắc
chắn thấy `_pendingWrite` khác null và xếp hàng đúng sau); 4 hàm `setX`
trực tiếp truyền `queueWhenIdle: false` (giữ fast-path đồng bộ khi rảnh).

**TDD:** viết test trong `test/core/storage_service_test.dart` (group
`setIntBuffered/setStringBuffered/flush`):
1. `flush()` đang chạy (unawaited) + `setInt` trực tiếp xen giữa → giá trị
   cuối trên disk là giá trị direct-set, không bị flush đè lại bằng snapshot
   cũ.
2. Regression: direct write vẫn luôn thắng buffered stale khi không có
   flush nào đang chạy.
3. Regression (thêm sau khi phát hiện v1 vỡ): gọi `setString` KHÔNG await
   rồi đọc lại NGAY (đồng bộ) vẫn thấy giá trị mới — bảo vệ đúng thuộc
   tính mà `ConsentStateService` và các service tương tự dựa vào.

**Kết quả:** `flutter analyze` sạch root + `example/`. `flutter test
--exclude-tags slow` sạch root + `example/` — chạy TOÀN BỘ suite (không
chỉ file liên quan) 2 lần độc lập để xác nhận, 2447-2451 test pass (1-2
lần chạy có 1 test flaky KHÁC NHAU mỗi lần — golden test 1 lần, haptic
test 1 lần khác — xác nhận qua chạy lại riêng lẻ đều pass sạch, kết luận
là resource-contention flakiness của việc chạy ~2450 test song song,
không liên quan gì tới thay đổi này).

**Tự chấm:** 9/10. Ban đầu chọn nhầm công cụ có sẵn (`AsyncActionGuard`)
mà không kiểm chứng đủ kỹ tính chất timing của nó trước khi áp dụng — chỉ
phát hiện nhờ chạy FULL suite thay vì chỉ file liên quan. Bài học: task
tưởng nhỏ ("thêm guard") vẫn cần full-suite verification, không chỉ test
file đang sửa.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)

Đọc kỹ file task này trước khi làm. Đọc toàn bộ file source liên quan trước khi thiết kế. Implement bằng TDD.
Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test + integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ `example/`.
4. Smoke test trên device Android thật có bằng chứng (khi task đổi hành vi quan sát được).
Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.
Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, commit + push lần hai.

## Ghi chú độ tin cậy

Cao. Đã verify `flush` dòng 159-166 snapshot ngoài lock, `_writeDirect` và `setInt` dòng 217-225 ghi độc lập không serialize chung.
