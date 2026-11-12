---
id: BUG-108
title: "signExport: dữ liệu có sẵn key _checksum ký xong nhưng không verify lại được"
type: bug
layer: lib/core/save_integrity
priority: P2
effort: S
source: "Scan SDK 2026-11-12; đã tái hiện bằng test tạm"
---

## Vị trí
`lib/core/save_integrity.dart:42-44` (`signExport` ghi đè key `_checksum` bằng `{...data, checksumKey: _hmac(data, secret)}`) và `:54-71` (`verifyAndStrip` xoá key đó rồi tính HMAC trên dữ liệu thiếu nó).

## Tái hiện (đã chạy)
`signExport({'coins': 5, checksumKey: 'x'}, 'k')` rồi `verifyAndStrip(signed, 'k')` ném `FormatException: checksum không khớp`. HMAC lúc ký tính trên map CÓ `_checksum: 'x'`, lúc verify tính trên map đã bỏ nó.

## Tác động
`signExport` được gọi ở 5 module (`diagnostics_export_bundle`, `disaster_recovery_save_export`, `economy_certificate`, `replay_recorder`, `reproduction_capsule`) với dữ liệu mà consumer ảnh hưởng được, nên một payload chứa key đó cho ra bản "đã ký" không bao giờ verify. Dữ liệu bị mất tính toàn vẹn khi cần khôi phục.

## Hướng sửa
Ném `ArgumentError` trong `signExport` nếu `data` đã chứa `checksumKey` (lỗi của người gọi, theo quy ước ENH-85). Test: ký dữ liệu chứa key đó phải ném `ArgumentError`; test cũ round-trip giữ xanh. Không thay đổi định dạng chữ ký.

## Tiêu chí xong
Test mới xanh, `api_snapshot` không đổi (hành vi, không đổi chữ ký), CHANGELOG ghi rõ lỗi trước đây im lặng.
