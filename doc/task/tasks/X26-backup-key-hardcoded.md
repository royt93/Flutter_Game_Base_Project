# X26 — Khoá AES-GCM backup hard-code trong binary → giả mạo save được

**Epic:** E6 Hardening · **SP:** 3 · **Pri:** Should · **Mức:** P2 (tech debt)
**Deps:** — · **Liên quan:** [[X18]] [[X25]]
**Trạng thái:** ✅ Done (2026-08-11) — **hướng A** (PO chốt)

## Vấn đề
`backup_code.dart:8-45` chứa nguyên một khoá 256-bit dạng byte literal, dùng
chung cho **mọi thiết bị, mọi bản cài đặt**. AES-GCM chỉ chống sửa dữ liệu
khi khoá là bí mật; ở đây khoá nằm trong source và trong APK.

### Kịch bản tái hiện
1. Trích khoá từ dòng 12-45 (hoặc dump từ APK).
2. Giải mã một mã `BK2` bất kỳ.
3. Sửa `coins` / `unlockedLevel` / achievement trong JSON.
4. Mã hoá lại bằng chính khoá đó.
5. Import — code xác thực GCM **chấp nhận**, vì attacker có đúng khoá nên
   MAC hợp lệ.

Nói cách khác: lớp mã hoá hiện tại chống được *sửa nhầm/hỏng file*, nhưng
không chống được *cố ý giả mạo* — dù cách viết code gợi ý rằng nó chống được.

## Vì sao chỉ P2 (và cần PO chốt mức)
Game **không có backend, không có IAP, không có leaderboard thật** (bot
tĩnh, xem `*_leaderboard_bots.dart`). Người chơi giả mạo save của chính mình
chỉ tự phá trải nghiệm của mình — không có nạn nhân thứ hai, không có doanh
thu bị mất.

Nhưng có **hai hệ quả thật**:
1. Kết hợp với [[X18]]: backup giả mạo là đường đưa JSON hỏng vào máy nạn
   nhân → app không boot được. Đó là tấn công có nạn nhân.
2. Code *trông như* có bảo mật thật. Người sau sẽ tin tưởng nó ở chỗ không
   nên tin (ví dụ khi thêm leaderboard thật, hoặc IAP sau này).

## Quyết định cần PO chốt
Chọn 1 trong 3 hướng, ghi lại lựa chọn vào file này trước khi code:

| Hướng | Việc | Đánh giá |
|---|---|---|
| **A. Ghi rõ giới hạn (khuyến nghị)** | Giữ nguyên code, thêm doc comment nói rõ "khoá này chỉ chống hỏng dữ liệu và người dùng nghịch tay, KHÔNG chống giả mạo có chủ đích — không dựa vào nó cho bất cứ thứ gì có giá trị". Đổi tên hàm cho đúng nghĩa (`obfuscate`/`checksum`, không phải `encrypt`). | SP 1. Trung thực, không giả vờ an toàn. Đủ cho game offline không doanh thu. |
| **B. Khoá theo thiết bị** | Sinh khoá ngẫu nhiên lần đầu chạy, lưu vào Keychain/Keystore. | SP 5. **Phá tính năng chính**: backup sẽ không chuyển được sang máy khác — đó chính là lý do backup tồn tại. Không nên. |
| **C. Ký phía server** | Cần backend. | Ngoài phạm vi (game cố ý không có backend). |

**Đề xuất: A.** Vấn đề thật ở đây không phải "khoá yếu" mà là "code nói dối
về mức bảo đảm nó cung cấp". Sửa lời nói dối rẻ hơn và đúng hơn là xây thứ
bảo mật mà mô hình đe doạ không cần.

## Acceptance criteria (cho hướng A)
- [x] Doc comment trên `_backupKey` nêu rõ mô hình đe doạ: **chống được** mã
      hỏng khi copy-paste và người dùng nghịch tay; **không chống được** giả
      mạo có chủ đích (ai đọc file này cũng có khoá).
- [x] Tên hàm/hằng không gợi ý bảo đảm mạnh hơn thực tế — đã đổi tên.
- [x] Đường import backup chịu được payload hỏng/độc: [[X18]] (hydrate có
      guard) và [[X25]] (`kMaxBackupCodeLength`) đều đã xong. **Đây mới là
      phần bảo vệ thật sự có giá trị.**
- [x] Ghi rõ điều kiện phải xem lại file: thêm leaderboard online, IAP, hoặc
      vật phẩm trao đổi được.

## Đã sửa
Đổi tên (giá trị prefix `'BK2:'` **giữ nguyên** — đó là định dạng đã phát
hành, đổi sẽ làm hỏng mọi mã backup người chơi đang giữ):

| Cũ | Mới |
|---|---|
| `encodeSecureBackupCode` | `encodeBackupCode` |
| `decodeSecureBackupCode` | `decodeBackupCode` |
| `secureBackupCodePrefix` | `backupCodePrefix` |
| `secureBackupCodeVersion` | `backupCodeVersion` |

Cập nhật 6 call site (`settings_screen.dart`, 4 test, 1 integration test).
Doc của `encodeBackupCode` đổi từ "tamper-evident, automatically encrypted"
sang "đóng gói save chia sẻ được, có phát hiện hỏng dữ liệu", và
`decodeBackupCode` ghi rõ `null` nghĩa là "không đọc được", **không** phải
"chắc chắn chưa bị sửa".

## Không đổi
Thuật toán, khoá, định dạng mã — tất cả giữ nguyên. Task này không tăng bảo
mật thực tế một chút nào, và đó là chủ đích: vấn đề thật không phải "khoá
yếu" mà là "code nói dối về mức bảo đảm nó cung cấp". Người sửa file này lần
sau sẽ không còn nhầm AES-GCM ở đây là chống-giả-mạo.

## Ghi chú kỹ thuật
Không xoay khoá, không thêm lớp obfuscation. Bất kỳ khoá nào nằm trong client
đều trích được; thêm lớp chỉ tăng chi phí bảo trì mà không đổi mô hình đe doạ.

DoD chung: `../README.md`.
