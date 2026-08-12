# X31 — Chuỗi tiếng Việt hard-code trong màn Raid Boss

**Epic:** E6 Hardening · **SP:** 1 · **Pri:** Should · **Mức:** P2
**Deps:** — · **Phát hiện bởi:** `test/widget/raid_boss_screen_test.dart`
**Trạng thái:** ✅ Done (2026-08-12)

## Bug

`raid_boss_screen.dart` ghi thẳng chữ "xu" tiếng Việt ở hai chỗ:

```dart
Text('${tier.coinReward} xu', ...)                       // bảng mốc thưởng
Get.snackbar('raid_boss_title'.tr, '+$claimed xu');      // sau khi nhận
```

App hỗ trợ **22 locale** (`AppTranslations.supported`). 21 trong số đó hiện
chữ Việt lẫn giữa giao diện đã dịch — và đây là bảng **phần thưởng**, tức là
đúng chỗ người chơi cần đọc hiểu con số.

## Đã sửa

Dùng lại key `coins_short` đã có sẵn ở đủ 22 locale (`'coins'` / `'xu'` /
`'monedas'` / `'pièces'` / `'Münzen'` …). Không thêm key mới nên không phải
động vào 22 map dịch.

## Kiểm chứng

- `test/widget/raid_boss_screen_test.dart` — ca "X31: nhãn xu dịch theo
  locale": màn chạy dưới locale `en`, đối chiếu từng mốc với
  `'coins_short'.tr` và chốt `find.textContaining(' xu')` phải rỗng.
- **Mutation-check:** trả lại chuỗi cứng `'${tier.coinReward} xu'` → đỏ.

## Quét phần còn lại

`grep` toàn `lib/presentation/` không còn chuỗi tiếng Việt hard-code nào khác
kiểu này. Hai chỗ trên là toàn bộ.
