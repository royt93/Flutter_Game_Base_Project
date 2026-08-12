# X29 — Buffer ghi-đệm nuốt mọi lần ghi thẳng sau đó

**Epic:** E6 Hardening · **SP:** 2 · **Pri:** Must · **Mức:** P1
**Deps:** [[X24]] (nguồn gốc) · **Phát hiện bởi:** `integration_test/undo_test.dart` trên máy thật
**Hồi quy của:** [[X24]] · **Che mất:** [[X17]]
**Trạng thái:** ✅ Done (2026-08-12)

## Bug

[[X24]] thêm write-behind buffer để hot path (`registerPop`) không ghi đĩa mỗi
cú tap. Nhưng 4 setter ghi thẳng — `setInt`/`setBool`/`setDouble`/`setString` —
**không xoá `_buffer[key]`**:

```dart
Future<void> setInt(String key, int value) async {
  platformWrites++;            // <- thiếu _buffer.remove(key)
  if (_prefs != null) { await _prefs.setInt(key, value); return; }
  _fallback[key] = value;
}
```

`_raw()` tra buffer trước `_prefs`, nên sau khi ghi thẳng:

1. mọi lần **đọc** vẫn ra giá trị đệm cũ;
2. cú **`flush()`** kế tiếp ghi giá trị đệm cũ đè lên đĩa.

Ghi thẳng trở thành no-op — lặng lẽ, không exception, không log.

### Phạm vi rộng hơn cái nó làm hỏng đầu tiên

Bất kỳ key nào từng đi qua hot path rồi được ghi thẳng đều dính:

| Đường ghi thẳng | Hậu quả khi bị nuốt |
|---|---|
| `restoreUndoCounters()` ([[X17]]) | counter đời không lùi trên đĩa → farm lại được sau khi kill app |
| `resetProgress()` ([[X19]]) | key vừa xoá sống lại ở lần flush sau |
| `importAll()` (backup) | giá trị khôi phục bị đè bằng save cũ |
| Giao dịch mua bán | chỉ an toàn nhờ tình cờ không trùng key hot path |

Tức là [[X17]] **chưa bao giờ chạy đúng end-to-end** kể từ khi [[X24]] vào,
dù unit test của nó xanh — vì unit test chỉ so `Rx.value` trong bộ nhớ.

## Cách phát hiện

`integration_test/undo_test.dart` (ca `X17: counter đời lùi theo undo`) chạy
trên Samsung S24 Ultra:

```
Expected: <0>
  Actual: <3>
```

Ba assertion trong bộ nhớ ngay phía trên đều xanh; chỉ assertion đọc **đĩa**
sau `flush()` đỏ. Đây đúng là loại lỗi integration test sinh ra để bắt và unit
test không thể thấy.

## Đã sửa

`lib/core/storage_service.dart` — thêm `_buffer.remove(key)` vào đầu cả 4
setter ghi thẳng, kèm ghi chú giải thích. `flush()` vẫn an toàn: nó
`_buffer.clear()` trước vòng lặp nên `remove` bên trong là no-op.

## Kiểm chứng

- `test/presentation/hot_path_writes_test.dart` — nhóm `X29` (4 ca): đọc sau
  ghi thẳng, `flush` không hồi sinh giá trị đệm, `setString` tương tự, và bản
  thu nhỏ của ca undo (bộ nhớ **và** đĩa cùng lùi).
- **Mutation-check:** gỡ cả 4 dòng `_buffer.remove(key)` → `+4 -4`, cả 4 ca
  X29 đỏ. Không có ca nào vô nghĩa.
- `integration_test/undo_test.dart` — 4/4 xanh trên S24 Ultra sau khi sửa
  (trước đó 3/4).
- Toàn bộ suite: 1137 xanh, `flutter analyze` 0 issue.

## Bài học

Buffer đọc-ghi luôn có hai nửa: đọc phải tra buffer trước, **và** ghi thẳng
phải huỷ buffer. [[X24]] làm nửa đầu (getters, `remove`, `exportAll`,
`allKeys`, `importAll` đều đã xử lý) nhưng bỏ nửa sau — chính xác vì nửa sau
không có triệu chứng nào ngoài đĩa.

Kéo theo: **mọi lỗi hoàn tác/reset/khôi phục cần một assertion đọc đĩa sau
`flush()`**, không chỉ so `Rx.value`.
