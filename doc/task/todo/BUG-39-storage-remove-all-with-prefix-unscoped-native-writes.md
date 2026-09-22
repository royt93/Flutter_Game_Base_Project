---
id: BUG-39
title: "removeAllWithPrefix xóa và ghi lại TOÀN BỘ SharedPreferences thay vì chỉ các key khớp prefix"
type: bug
priority: P1
effort: M
source: "agy (độc lập), verify lại qua Read lib/core/storage_service.dart:344-434 — đối chiếu với doc/task/done/IDEA-55 (nơi đã thử và không thể test full atomicity với shared_preferences ^2.5.5 hiện tại)"
---

## Vị trí
`lib/core/storage_service.dart` — `removeAllWithPrefix(prefix)` (dòng ~356) gọi `importAll(remaining)`, và `importAll`/`_replaceAll` (dòng ~306-419) xóa **mọi** key hiện có trong `SharedPreferences` (không chỉ key khớp `prefix`) rồi ghi lại toàn bộ map `remaining`.

## Hiện trạng
`_replaceAll` thực hiện:
```dart
for (final key in prefs.getKeys().toList()) {
  await prefs.remove(key);
}
```
tức là xóa lần lượt TỪNG key gốc trên toàn bộ `SharedPreferences` (âm thanh, ngôn ngữ, theme, mọi save slot khác...), rồi mới ghi lại `remaining` (dữ liệu hiện có TRỪ các key thuộc `prefix`). `importAll` có bọc `try/catch` để re-apply snapshot cũ nếu `_replaceAll` NÉM một exception Dart (đã xác nhận qua `doc/task/done/IDEA-55`), nhưng **không có gì bảo vệ khỏi process bị OS kill/crash phần cứng đúng giữa vòng lặp xóa** — lúc đó catch không chạy được vì process đã chết, và toàn bộ profile (không chỉ 1 save slot) mất trắng.

## Vì sao cần / Hậu quả
`SaveSlotManager.deleteSlot()` gọi đúng đường này để xóa 1 slot. Nếu thiết bị bị low-memory-kill hoặc crash phần cứng đúng lúc `_replaceAll` đang xóa (trước khi ghi lại xong), TOÀN BỘ dữ liệu app (không chỉ slot bị xóa) biến mất vĩnh viễn, không rollback được (rollback chỉ hoạt động cho exception Dart, không sống sót qua process kill). Ngoài ra việc xóa-rồi-ghi-lại toàn bộ key gây bão IPC native không cần thiết chỉ để xóa vài key thuộc 1 prefix.

`doc/task/done/IDEA-55` đã thử nghiệm và xác nhận **không thể** giả lập lỗi ghi thật (process/platform-level failure) với `shared_preferences ^2.5.5` hiện tại trong unit test — nên task này KHÔNG yêu cầu chứng minh full atomicity bằng test giả lập process-kill (đã biết bất khả thi), mà tập trung vào giảm blast radius: chỉ động tới key thuộc đúng `prefix`, không đụng key khác.

## Đề xuất
Đổi `removeAllWithPrefix` để xóa trực tiếp chỉ các key khớp `prefix` (native `prefs.remove(k)` cho từng key thuộc prefix), không đi qua `_replaceAll`/`importAll` nữa — loại bỏ hoàn toàn rủi ro đụng tới key không liên quan:
```dart
Future<void> removeAllWithPrefix(String prefix) async {
  if (prefix.isEmpty) throw ArgumentError.value(prefix, 'prefix', 'must not be empty');
  _buffer.removeWhere((k, _) => k.startsWith(prefix));
  final prefs = _prefs;
  if (prefs != null) {
    for (final k in prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      await prefs.remove(k);
    }
  } else {
    _fallback.removeWhere((k, _) => k.startsWith(prefix));
  }
}
```
Cập nhật doc comment để không còn tuyên bố "same rollback-on-error guarantee as importAll" (không còn đúng/không còn cần thiết vì không còn đi qua `_replaceAll` nữa).

## Acceptance criteria
- [ ] `removeAllWithPrefix(prefix)` chỉ gọi `prefs.remove()`/xóa buffer cho đúng các key khớp `prefix`; không key nào khác trong storage bị đụng tới (verify bằng test: seed vài key ngoài prefix, gọi `removeAllWithPrefix`, assert các key ngoài prefix + giá trị của chúng KHÔNG đổi).
- [ ] Test cũ liên quan tới `removeAllWithPrefix` (IDEA-56, ENH-77) vẫn pass nguyên vẹn.
- [ ] `prefix` rỗng vẫn throw `ArgumentError` như cũ.
- [ ] Fallback in-memory map (khi `SharedPreferences` chưa sẵn sàng) cũng chỉ xóa đúng key khớp prefix.
- [ ] Doc comment của `removeAllWithPrefix` không còn tuyên bố sai về cơ chế rollback không còn áp dụng.
- [ ] Không phá bất kỳ test nào khác trong `test/core/storage_service_test.dart`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-39-storage-remove-all-with-prefix-unscoped-native-writes.md` này trước khi làm. Đọc toàn bộ `lib/core/storage_service.dart` (đặc biệt `importAll`/`_replaceAll`/`removeAllWithPrefix`/`exportWithPrefix`/`importWithPrefix`) và `test/core/storage_service_test.dart` hiện có, cùng `doc/task/done/IDEA-55-storage-service-erase-all.md` (đã ghi lại lý do KHÔNG thể test process-kill atomicity với `shared_preferences` hiện tại — đừng lặp lại nỗ lực đó). Implement bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria (không cần widget/integration test — đây là thay đổi thuần logic storage).
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (thay đổi không đổi hành vi người dùng quan sát được trực tiếp, chỉ giảm blast-radius của 1 lỗi hiếm — refactor nội bộ).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — đã tự đọc trực tiếp `lib/core/storage_service.dart:344-419` xác nhận `_replaceAll` xóa toàn bộ `prefs.getKeys()` chứ không lọc theo prefix, đúng như agy mô tả. Đã đối chiếu `doc/task/done/IDEA-55-storage-service-erase-all.md` để xác nhận rollback-on-error CHỈ bảo vệ exception Dart trong `importAll`, không bảo vệ process-kill — nên P0 gốc của agy được hạ xuống P1 (rủi ro thật nhưng hiếm, và fix không cần "chứng minh" atomicity bất khả thi, chỉ cần giảm blast radius). Không trùng bất kỳ task nào trong `doc/task/done/`.
