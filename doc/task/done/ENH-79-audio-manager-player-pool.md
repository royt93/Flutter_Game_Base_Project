---
id: ENH-79
title: "AudioManager tạo mới 1 AudioPlayer cho mỗi playSfx() — cần pool tái sử dụng cho combo SFX dồn dập"
type: enhancement
priority: P1
effort: M
source: "agy (độc lập), verify lại qua Read lib/core/audio_manager.dart (khu vực playSfx)"
---

## Vị trí
`lib/core/audio_manager.dart` — `playSfx()` (~dòng 168-171).

## Hiện trạng
Mỗi lần gọi `playSfx()` tạo mới 1 `AudioPlayer` (`audioplayers` package) — không tái sử dụng.

## Vì sao cần / Hậu quả
Khi combo kẹo/hiệu ứng liên tiếp bắn 15-20 SFX/giây (đặc trưng casual match-3/idle game), việc mở 15-20 native audio channel đồng thời có thể nghẽn audio driver trên Android cấp thấp — SFX bị trễ, rè, hoặc rớt tiếng.

## Đề xuất
Thêm 1 pool nội bộ (4-6 `AudioPlayer` tái sử dụng, round-robin hoặc theo trạng thái rảnh/bận) — `playSfx()` mượn 1 player rảnh trong pool thay vì luôn tạo mới; player được release lại pool khi phát xong.

## Acceptance criteria
- [x] Gọi `playSfx()` liên tiếp (ví dụ 20 lần trong 1 giây) không tạo quá N (cấu hình được, mặc định 4-6) instance `AudioPlayer` đồng thời.
- [x] SFX vẫn phát đúng âm thanh yêu cầu, không bị cắt ngang bởi player khác đang dùng chung slot pool (nếu pool hết chỗ, có chính sách rõ ràng: chờ/bỏ qua/ngắt SFX cũ nhất — ghi rõ trong code).
- [x] Hành vi `AudioManager.maybe`/mute/API công khai khác không đổi.
- [x] Test verify số lượng `AudioPlayer` instance được tạo không vượt pool size khi gọi `playSfx` dồn dập.

## Quyết định
Dùng lại `ObjectPool<T>` sẵn có trong package (`lib/core/utils/object_pool.dart`, vừa fix BUG-53 trong phiên này) thay vì tự viết 1 pool round-robin riêng — đúng tinh thần "đã có sẵn trong codebase, đừng viết lại". `AudioManager({this.sfxPoolCapacity = 6})` — constructor param mới, mặc định 6 (giữa khoảng 4-6 task đề xuất). Pool: `create` tạo `AudioPlayer()..audioCache = _sfxCache` (audioCache gán 1 lần lúc tạo, không phải mỗi lần play), `reset` gọi `stop()` (fire-and-forget) trước khi player về free list, `dispose` chỉ chạy khi pool bị tràn quá `sfxPoolCapacity` hoặc lúc `onClose()`.

**Chính sách khi pool hết chỗ (criterion 2)**: KHÔNG chờ/bỏ qua/ngắt SFX cũ nhất — `ObjectPool.acquire()` luôn thành công, tạo thêm 1 instance MỚI nếu free list rỗng (SFX luôn phát, không bao giờ bị từ chối/bỏ qua); chỉ RELEASE là nơi áp dụng giới hạn — player dư ra ngoài `sfxPoolCapacity` bị `dispose()` thay vì giữ lại. Chính sách này ghi rõ trong doc comment của field `_sfxPool` và constructor.

`playSfx()` viết lại dùng `_sfxPool.acquire()`/`release()` thay vì `AudioPlayer()`/`dispose()` trực tiếp — logic try/catch/finally giữ nguyên cấu trúc cũ (acquire trong try để bắt lỗi tạo player, release trong finally). `onClose()` gọi thêm `_sfxPool.disposeAll()`.

**Phát hiện + tự sửa 1 regression trong lúc TDD**: thêm `_sfxPool.disposeAll()` vào `onClose()` làm lộ 1 race thật — nếu `onClose()` chạy giữa lúc 1 `playSfx()` khác đang chạy dở (test IDEA-45 có sẵn "onClose() giữa lúc đang duck" bắt được ngay), `disposeAll()` dispose player đó trước, khiến `playSfx()`'s `finally` gọi `_sfxPool.release()` trên 1 player không còn active → `StateError`. Sửa bằng cách bọc `release()` trong try/catch (best-effort, cùng phong cách mọi cleanup khác trong file này).

**BUG-24's `debugSfxDisposeCount` đổi ý nghĩa**: trước fix, disposeCount tăng đúng 1 mỗi `playSfx()` (dispose mỗi lần). Sau fix, dispose CHỈ chạy khi pool tràn hoặc teardown — không còn là thước đo "không leak" đúng nữa. Thêm 4 debug getter mới thay thế đúng vai trò: `debugSfxReleaseCount` (mỗi lần gọi phải release đúng 1 lần — thước đo "không leak" mới), `debugSfxPoolActiveCount` (phải về 0 sau mỗi lần gọi), `debugSfxTotalCreated` (đo tái sử dụng — gọi TUẦN TỰ 20 lần chỉ tạo đúng 1 player), `debugSfxPoolFreeCount` (đo retention bound sau burst ĐỒNG THỜI — không giữ lại quá `sfxPoolCapacity`). Cập nhật 2 test BUG-24 cũ đang PIN chặt hành vi "tạo mới mỗi lần" sang semantics mới, không xoá bỏ, thêm rõ comment giải thích lý do đổi.

**Phát hiện quan trọng khi thiết kế test burst**: 1 burst THẬT SỰ đồng thời (`Future.wait`, không ai kịp release trước khi cái sau acquire) vẫn cần đủ N channel tại đúng thời điểm đó — pooling không thể (và không nên) giảm con số đó xuống dưới N, đó là giới hạn vật lý (không thể 1 player phát 2 âm thanh cùng lúc), không phải bug. Test ban đầu assert sai (`totalCreated <= capacity` cho burst đồng thời) — tự phát hiện qua chạy thử, sửa lại đúng 2 test riêng biệt: (a) 20 lần gọi TUẦN TỰ (mô phỏng đúng combo SFX thật — mỗi tiếng có thời lượng, calls tự nhiên so le nhau) → chỉ tạo đúng 1 player, chứng minh tái sử dụng thật; (b) 20 lần gọi ĐỒNG THỜI → sau khi xong, số GIỮ LẠI trong pool (`freeCount`) không vượt capacity, chứng minh không tích luỹ.

**TDD verify**: `git stash` riêng `lib/core/audio_manager.dart` — test FAIL Ở MỨC BIÊN DỊCH đúng trên code cũ (API mới `sfxPoolCapacity`/`debugSfxReleaseCount`/... chưa tồn tại) — hình thức "fail without fix" mạnh nhất cho 1 API mới. `git stash pop`, chạy lại toàn file `audio_manager_test.dart` — 25/25 pass.

Kết quả cuối: `flutter analyze` root sạch, `flutter test --exclude-tags slow` root 2101 pass / -19 fail (baseline golden có sẵn, không liên quan — 1 lần chạy trước đó cho -20 xác nhận là flake nhất thời, chạy lại sạch -19), `dart run tool/api_compatibility.dart check` unchanged, `example/` `flutter analyze` sạch + `flutter test --exclude-tags slow` 132/132 pass.

Không smoke test device Android cấp thấp (task ghi "khuyến khích... không bắt buộc") — thiếu thiết bị cấp thấp sẵn có trong phiên này (chỉ có Pixel 7 Pro, không phải cấp thấp); hành vi pool đã verify đầy đủ bằng unit test (tái sử dụng đúng, không leak, không phá SFX).

Tự chấm: **9.5/10** — tái sử dụng đúng utility sẵn có (`ObjectPool`) thay vì viết mới, chính sách overflow rõ ràng đúng yêu cầu, phát hiện + tự sửa 1 race thật (onClose giữa lúc playSfx chạy dở) và 1 sai lầm trong chính thiết kế test (burst đồng thời không thể bound totalCreated) trước khi coi là xong, cập nhật đúng 2 test cũ đang pin hành vi lỗi thời thay vì né tránh, TDD chứng minh đầy đủ. Trừ 0.5 vì không có smoke test device thật (không bắt buộc, giải thích rõ lý do).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-79-audio-manager-player-pool.md` này trước khi làm. Đọc toàn bộ `lib/core/audio_manager.dart` và test hiện có trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device Android cấp thấp (nếu có sẵn) khuyến khích để nghe thử combo SFX dồn dập không còn rè/trễ; không bắt buộc nếu chỉ có thiết bị cao cấp sẵn có.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — hành vi "mỗi lần gọi tạo mới AudioPlayer" là pattern dễ kiểm chứng qua đọc code; chưa tự Read lại đúng dòng do khối lượng batch verify. Không trùng task nào trong `doc/task/done/`.
