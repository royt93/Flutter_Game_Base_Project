---
id: FEAT-42
title: "RewardTransactionPipeline — reward idempotent xuyên suốt ad/IAP/quest/wallet"
type: feature
layer: game/logic
priority: P0
effort: L
depends_on: [FEAT-31, FEAT-34, FEAT-37, FEAT-38, IDEA-33]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn một transaction ID đi từ nguồn reward tới wallet/save/analytics để callback lặp không cấp thưởng hai lần.

## Sprint slices
- Model source, transaction id, reward lines, status và receipt metadata không chứa secret.
- Validate → reserve id → atomic grant → persist → emit event; resume transaction dang dở.
- Adapter cho rewarded ad, purchase seam, daily quest/login.
- Audit trail bounded và reconciliation API.

## Acceptance criteria
- [x] Cùng transaction id chỉ grant một lần qua concurrent callback và restart.
- [x] Partial failure có resume/rollback xác định, balance không lệch ledger.
- [x] Invalid/corrupt/tampered reward bị từ chối trước mutation.
- [x] Analytics failure không rollback reward đã commit.

## Prompt loop feature
Đọc task và dependencies; viết transaction state machine/threat cases trước TDD. End loop: audit changes, chấm /10; unit test + widget test + integration test mọi success/duplicate/race/crash-recovery/corrupt case; analyze/test root + example; smoke device thật chứng minh double callback không double grant. Chỉ khi work và điểm >9/10 mới commit + push; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Thiết kế trình bày với owner trước khi code (task effort L, chạm reward/tiền integrity) — approved đúng như đề xuất, KHÔNG mở rộng thêm spend-line hay auto-hook `resumePending()` vào bootstrap (giữ scope L, không lấn XL).

Thêm `RewardTransactionPipeline` (`lib/core/reward_transaction_pipeline.dart`), orchestration layer MỎNG phía trên `EconomyWallet` (FEAT-31) — không sửa `EconomyWallet`:
- `RewardLine {currency, amount}`, `RewardSource {ad, purchase, dailyQuest, dailyLogin, other}` (mô tả nguồn, không rẽ nhánh hành vi), `RewardTransactionRecord {transactionId, source, lines, status, createdAtMs, receiptMeta}`.
- `RewardTransactionStatus` chỉ 3 trạng thái `pending/partial/committed` — KHÔNG có `failed` terminal: request sai bị từ chối trước khi tạo record nào, nên mọi record đã persist đều resumable.
- `grant()`: validate toàn bộ request trước (transactionId/lines rỗng, currency rỗng, amount<=0) → từ chối, KHÔNG đụng gì → ghi record `pending` → gọi `wallet.earn` tuần tự từng line với id dẫn xuất `'$transactionId#$i'` (theo INDEX, không theo currency — tránh 2 line cùng currency trong 1 transaction bị đè id) → line nào fail thì dừng, record `partial`, KHÔNG rollback line trước (line trước đã commit ở tầng wallet, giữ nguyên) → hết line thành công thì record `committed`, bắn `onGranted` (Rx, theo đúng convention `.obs` GetX toàn repo) rồi gọi analytics trong try/catch riêng (throw không ảnh hưởng kết quả trả về).
- Toàn bộ `grant()` bọc trong `AsyncActionGuard.runExclusive('pipeline', ...)` (tái dùng FEAT-34, không tự chế guard mới) — serialize giữa các lần gọi pipeline, tách biệt guard nội bộ `'wallet'` của `EconomyWallet`.
- Audit trail persist qua `wallet.storage` (không cần param storage riêng), bounded FIFO (default 200, ghi đè được qua constructor cho test) — cùng trade-off đã document ở `EconomyWallet._transactions`.
- `resumePending()`: quét record `pending`/`partial`, gọi lại `grant()` — an toàn vì mỗi line dedup độc lập ở tầng wallet.
- Adapter `grantFromDailyQuest`/`grantFromDailyLogin`/`grantFromPurchase` chỉ là wrapper mỏng suy ra `transactionId`/`source` rồi gọi `grant()` — không có "ad seam" thật trong SDK này nên reward quảng cáo dùng thẳng `grant(source: RewardSource.ad, ...)`.
- Earn-only theo đúng phạm vi đã chốt — spend đi thẳng `EconomyWallet.trySpend`, không qua pipeline này.
- `createdAtMs` dùng `DateTime.now()` thẳng (không qua `nowMsClamped()`) — đây chỉ là audit metadata hiển thị, không phải cổng chống gian lận, và `nowMsClamped()` cần `StorageService.to` đăng ký qua Get (ambient), không khớp cách constructor-inject storage của cả `EconomyWallet` lẫn pipeline này.
- Export public: thêm dòng `export` trong `lib/roy_casual_kit.dart` (không chỉ trong barrel con) — chạy `dart run tool/api_compatibility.dart snapshot` cập nhật `tool/api_snapshot.json`, thêm mục CHANGELOG.md tương ứng (bắt buộc — công cụ check phát hiện thiếu changelog khi có export mới).

**Test:** `test/core/reward_transaction_pipeline_test.dart` (14 case, pure Dart + Flutter test binding, TDD — RED xác nhận trước khi viết `reward_transaction_pipeline.dart`): reject invalid trước mutation, grant 1 line, grant nhiều line không đụng nhau, gọi lại cùng id không cộng thêm, concurrent trùng id chỉ cộng 1 lần, restart đọc lại đúng audit trail không cộng lại, partial failure (overflow giả lập) giữ line trước + `resumePending()` hoàn tất sau khi hết lỗi, analytics throw không ảnh hưởng kết quả, audit trail bounded loại record cũ nhất, 3 adapter tiện ích, `onGranted` phát đúng record, `.maybe`.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1284/1284 pass (1 lần chạy đơn lẻ trước đó gặp `season_event_service_test.dart` flaky pre-existing do đua thời gian thực 1ms — không liên quan, đã verify pass riêng lẻ). example `flutter analyze` sạch, example `flutter test --exclude-tags slow` 55/55 pass (không cần đụng UI showcase — task thuần logic, không có acceptance nào yêu cầu UI). `dart run tool/api_compatibility.dart check` → unchanged sau khi snapshot lại. `dart pub publish --dry-run` → 1 warning (working-tree chưa commit, hết ngay sau commit).

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): thêm 1 `testWidgets` mới vào `example/integration_test/app_boot_test.dart` (đúng convention BUG-35/FEAT-31/FEAT-38 — mỗi feature 1 case trong file chung) — 2 `pipeline.grant()` concurrent cùng `transactionId` trên `StorageService.to` thật, verify balance/audit trail không double-grant. Chạy `flutter test integration_test/app_boot_test.dart -d 2B051FDH3006MU --dart-define=E2E_TEST=true --plain-name "FEAT-42"` (lọc riêng, đúng convention evidence log cũ — chạy KHÔNG lọc lần đầu vô tình đụng phải lỗi audioplayers "animation still running" pre-existing ở 2 test khác SAU dòng có `app.app(withAudio: true)` trong cùng 1 binary integration test dài, không liên quan FEAT-42, đã verify FEAT-42's own case pass sạch trong cả 2 lần chạy). Evidence: `doc/task/evidence/FEAT-42-device-smoke.log`.

**Tự chấm điểm: 9.5/10** — trình bày thiết kế và xin approval trước khi code (task L chạm tiền, đúng tinh thần thận trọng), tận dụng tối đa hạ tầng có sẵn (idempotency của `EconomyWallet`, `AsyncActionGuard`, `SdkResult`, `safe_json`) thay vì tự chế, giữ đúng scope đã chốt (earn-only, không auto-hook bootstrap), test đầy đủ mọi nhánh acceptance criteria kể cả partial-failure + resume, đúng convention integration test hiện có. Trừ 0.5 vì lần chạy device đầu tiên không lọc `--plain-name` nên tốn thời gian debug một false-positive từ lỗi pre-existing không liên quan trước khi nhận ra convention đúng.

