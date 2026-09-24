---
id: BUG-72
title: "AppVersionGate so sánh prerelease semver kiểu string thay vì numeric identifier đúng chuẩn"
type: bug
priority: P2
effort: S
source: "claude (fork audit round 2, độc lập)"
---

## Vị trí
`lib/core/app_version_gate.dart:73` (hàm so sánh version, nhánh so 2
prerelease với nhau).

## Hiện trạng
```dart
return va.prerelease!.compareTo(vb.prerelease!);
```
So sánh 2 chuỗi prerelease bằng `String.compareTo` — tức lexicographic
(so từng ký tự), không phải semver numeric-identifier đúng chuẩn (semver
spec: nếu 1 identifier trong prerelease là số thuần, phải so sánh SỐ, không
so chuỗi).

## Vì sao cần / Hậu quả
`"rc.2".compareTo("rc.10")` trả về dương (tức "rc.2" > "rc.10") vì so ký tự
'2' > '1' tại vị trí đó — SAI theo semver thật, đúng ra `rc.2 < rc.10` vì so
numeric.

Kịch bản thật: `minimumVersion = "1.2.3-rc.10"`, người chơi đang chạy
`"1.2.3-rc.2"` (build CŨ hơn thật, cần bị chặn/ép update) —
`evaluateVersionGate` sẽ tính sai là app hiện tại "mới hơn hoặc bằng"
minimum, KHÔNG force-update dù đúng ra phải chặn. Bug chỉ lộ ra khi release
train của 1 rc/beta vượt quá 9 (rc.10 trở lên) — dễ bị bỏ sót lúc test vì
số rc nhỏ thường không gặp vấn đề này.

## Đề xuất
Sửa hàm so sánh prerelease để tách theo dấu `.` thành từng identifier, với
mỗi identifier: nếu cả 2 phía đều là số thuần thì so numeric
(`int.parse` rồi so), ngược lại so string — đúng thuật toán semver spec
(mục 11 của semver.org). Không cần implement toàn bộ semver spec (ví dụ
không cần so "identifier số luôn nhỏ hơn identifier chữ" nếu file hiện tại
chưa cần) — chỉ cần sửa đúng phần đang sai (numeric identifier) mà không
phá các case khác đang pass.

## Acceptance criteria
- [x] `"1.2.3-rc.2"` so với `"1.2.3-rc.10"` phải cho kết quả đúng: `rc.2 <
      rc.10` (rc.2 CŨ hơn).
- [x] Case cũ (không có prerelease, prerelease vs không-prerelease, build
      metadata bị bỏ qua) trong `test/core/app_version_gate_test.dart` vẫn
      pass nguyên vẹn — không phá hành vi đã đúng.
- [x] Có test mới cho case 2 chữ số trở lên (rc.2 vs rc.10, rc.9 vs rc.10)
      VÀ ít nhất 1 case nhiều identifier hỗn hợp (ví dụ `alpha.1` vs
      `alpha.2` vs `beta.1`) để chứng minh không chỉ vá đúng 1 case cụ thể.
- [x] `evaluateVersionGate` (hàm cấp cao dùng hàm so sánh này) phải verify
      qua ít nhất 1 test end-to-end với case rc.2/rc.10 để chứng minh fix
      lan đúng lên tầng quyết định force-update, không chỉ đúng ở hàm so
      sánh thuần.

## Quyết định

**Implementation**: `lib/core/app_version_gate.dart` — thay
`va.prerelease!.compareTo(vb.prerelease!)` (string lexicographic) bằng hàm
mới `_comparePrerelease(a, b)`: tách theo dấu `.` thành từng identifier, so
từng cặp — nếu CẢ HAI phía parse được thành số nguyên (`int.tryParse`) thì
so numeric; nếu chỉ 1 phía là số thì số luôn thấp hơn chữ (đúng semver.org
§11); còn lại so string bình thường. Số field nhiều hơn (mọi field chung
đã bằng nhau) thì có precedence cao hơn — đúng chuẩn semver đầy đủ, không
chỉ vá đúng case rc.N cụ thể.

**TDD**: viết 8 test mới trước (5 test thuần cho `compareAppVersions` + 1
test end-to-end cho `evaluateVersionGate`) → `git stash` riêng file lib →
chạy: 3/6 test FAIL đúng dự đoán (`rc.2 vs rc.10`, `rc.9 vs rc.10`, và
`evaluateVersionGate` end-to-end — `Expected: GateDecision.forceUpdate,
Actual: GateDecision.ok`, đúng chứng minh bug lan tới tầng quyết định
thật), 3 case còn lại (identifier chữ, số-thấp-hơn-chữ, nhiều field hơn)
PASS cả trên code cũ vì không trúng đúng nhánh bug (string compareTo tình
cờ vẫn đúng cho các case không có số ≥ 2 chữ số). Khôi phục, chạy lại —
26/26 pass toàn file (18 test cũ + 8 mới).

**Kết quả**:
- `flutter analyze` (root): sạch.
- `dart run tool/api_compatibility.dart check`: `unchanged` (hàm mới
  `_comparePrerelease` là private, không lộ ra API công khai).
- `flutter test --exclude-tags slow` (root): 2350 test, 19 fail — đúng
  khớp 19 golden-image (macOS-vs-Linux) baseline đã biết, KHÔNG có flaky
  phát sinh thêm lần chạy này, không có regression.
- Không đụng `example/` nên không cần chạy analyze/test ở đó.
- Không cần smoke test device (task tự ghi rõ — pure logic so sánh version,
  unit test đã đủ chứng minh).

**Tự chấm điểm: 9.5/10.** Bug thật rất dễ verify (1 dòng Dart tái hiện
được ngay), fix đúng chuẩn semver spec đầy đủ (không chỉ patch case cụ thể
task nêu), có test end-to-end chứng minh fix lan đúng lên tầng quyết định
`GateDecision`. Trừ 0.5 vì chưa implement ĐẦY ĐỦ mọi quy tắc semver §11
(ví dụ thứ tự "identifier ít field hơn nhưng KHÔNG phải prefix của identifier
nhiều field" — trường hợp hiếm, không xuất hiện trong bất kỳ acceptance
criteria hay use case thật nào của gate này, nên cố ý không mở rộng thêm).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-72-app-version-gate-prerelease-lexicographic-compare.md`
này trước khi làm. Đọc TOÀN BỘ `lib/core/app_version_gate.dart` (hàm parse
version + hàm so sánh + `evaluateVersionGate`) và
`test/core/app_version_gate_test.dart` trước khi sửa — cần hiểu đúng cách
version được parse thành các phần (major/minor/patch/prerelease/build)
trước khi viết lại logic so sánh prerelease. Implement bằng TDD — viết test
trước, xác nhận fail trên code cũ với đúng lý do (rc.2 vs rc.10 cho kết quả
ngược), rồi mới sửa.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (unit test đủ chứng minh, đây là
   pure logic so sánh version).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ
test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các
checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ
`doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]`
khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — fork audit đã trích dẫn chính xác file:line, đưa ra ví dụ cụ thể
(`"rc.2".compareTo("rc.10")`) có thể verify ngay bằng 1 dòng Dart, xác nhận
`test/core/app_version_gate_test.dart` chưa có test nào so 2 prerelease từ
2 chữ số trở lên. Không trùng task nào trong `doc/task/done/`.
