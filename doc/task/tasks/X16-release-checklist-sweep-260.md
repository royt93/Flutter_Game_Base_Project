# X16 — Test suite đang đỏ: `RELEASE_CHECKLIST.md` chưa sweep "260 màn"

**Epic:** E6 Hardening · **SP:** 1 · **Pri:** Must · **Mức:** P0 · **Deps:** —
**Trạng thái:** ✅ Done (2026-08-11)

## Mục tiêu
Đưa `flutter test --exclude-tags slow` về xanh. Hiện đang **đỏ**.

## Hiện trạng (verify 2026-08-11)
```
flutter test test/tool/campaign_total_sweep_test.dart
00:02 +0 -1: doc/RELEASE_CHECKLIST.md: tổng số màn campaign khớp kLevelCount hiện tại [E]
  Expected: true
    Actual: <false>
  Không thấy "260 màn" trong RELEASE_CHECKLIST.md — có thể quên sweep sau khi kLevelCount đổi.
```
`kLevelCount` đã lên 260 ở commit `2b7b156` (feat: expand campaign to 260
levels) nhưng `doc/RELEASE_CHECKLIST.md` chưa được sweep theo. Đây đúng là
việc mà `campaign_total_sweep_test.dart` sinh ra để bắt — test đang làm đúng
nhiệm vụ, chỉ là chưa ai xử lý.

## Vì sao P0
DoD của **mọi** story yêu cầu `flutter test --exclude-tags slow` xanh. Suite
đang đỏ nghĩa là không story nào trong Round 9 có thể Done cho tới khi cái
này xong. Chi phí sửa: 1 dòng.

## User story
*As a* dev *I want* suite test xanh trước khi bắt đầu sprint *so that* mọi
failure tôi thấy sau đó đều là do thay đổi của tôi.

## Acceptance criteria
- [x] `doc/RELEASE_CHECKLIST.md` chứa chuỗi `260 màn` ở vị trí đúng ngữ nghĩa
      (số màn campaign), không phải nhét bừa để qua test.
- [x] `flutter test test/tool/campaign_total_sweep_test.dart` xanh cả 4 case.
- [x] `flutter test --exclude-tags slow` xanh toàn bộ (759 pass).
- [x] Sweep các doc **mô tả trạng thái hiện tại** — không còn chỗ nào nói sai
      tổng số màn/world/mode. (`doc/feat.md` **cố ý không sửa**: đó là
      changelog lịch sử, các câu "200 level"/"220 level" mô tả đúng trạng thái
      tại thời điểm entry được viết. Sửa chúng là làm sai lịch sử.)

## Đã sửa
1. `doc/RELEASE_CHECKLIST.md` dòng 3 — cả **3** số đều đã trôi, không chỉ số
   màn: `220 màn (11 world) + 9 side mode` → `260 màn (13 world) + 14 side mode`.
2. `test/tool/campaign_total_sweep_test.dart` — thêm 2 test suy thẳng từ
   `kWorlds.length` và `GameMode.values.length - 1`, nên số world/side mode
   cũng được khoá lại như số màn, không cần cập nhật tay mỗi round.

## Ghi chú
Đã cân nhắc quét luôn `doc/feat.md` + doc comment trong `levels.dart` và
**bỏ**: cả hai chứa số liệu lịch sử hợp lệ, test sẽ đỏ giả. Chỉ quét
`RELEASE_CHECKLIST.md` — file mô tả trạng thái hiện tại và là file người
verify release thật sự đọc.

DoD chung: `../README.md`.
