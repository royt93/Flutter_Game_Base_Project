---
id: DOC-3
title: "Ghi ngày và phạm vi cho bằng chứng smoke trên thiết bị thật"
type: docs
layer: docs/qa
priority: P2
effort: S
source: "Full source audit 2026-11-21; README proof recency and device matrix evidence scope differ"
---

## Quan sát

README có physical-device proof nhưng ngày/context có thể không rõ; QA matrix và release checklist chứa các mốc khác nhau. Bằng chứng install/launch smoke không tự chứng minh hành vi tương tác hoặc hiệu năng.

- `README.md`
- `docs/qa/device_matrix.md`
- `doc/task/RELEASE-0.6.3-INTAKE-CHECKLIST.md`

## Phạm vi

Chuẩn hóa metadata cho proof mới: date, device model/OS, app build/commit, flow cụ thể, result/log link; tách smoke launch, interactive behavior và performance claim. Không sửa lịch sử nếu không có raw evidence.

## Acceptance criteria

- [x] README và QA matrix ghi ngày, thiết bị/build, loại và giới hạn của proof hiện hành.
- [x] Record TECNO 2026-09-26 giữ nguyên như lịch sử; metadata thiếu được ghi unknown, không tự nâng claim.
- [x] QA matrix có format chung dùng cho README summary và record chi tiết.
- [x] Link/path và metadata checks pass; không chạy unit/widget/integration vì docs-only.
- [x] Audit đạt >9/10 theo rubric bên dưới.
- [x] Không cần run thiết bị mới; chỉ đối chiếu evidence physical S24U đã có, không dùng simulator hay giả số đo.

## Prompt loop

Đọc README, QA device matrix và release intake; đối chiếu dates/details, nhưng không suy diễn log không tồn tại. Tạo proof schema nhỏ phân biệt launch, behavior, perf. Chỉ cập nhật proof có raw evidence; gắn stale label khi cần. Chạy doc/link checks và audit mọi claim/path. Chấm /10 theo rubric; lặp tới >9/10. Nếu muốn thu thập evidence mới nhưng thiết bị không có hoặc test có ad/live side effect không đảm bảo an toàn, dừng và hỏi owner. Khi acceptance đạt, ghi kết quả rồi push theo yêu cầu owner.

## Kết quả thực hiện

- Audit / điểm: **9.5/10** — evidence accuracy 4.5/5 (metadata/log gốc của lần TECNO lịch sử và raw benchmark log không được lưu, đã ghi rõ); reproducibility 3/3; scope 1/1; checks 1/1. Không nâng install/launch thành feature/performance proof.
- Proof metadata: baseline S24U `SM-S928B`, Android 16, debug integration, source `d6ae94f2`; baseline commit `d3a9326c`, value `32952ms`, `recordedAtMs=1795277550507` (2026-11-21 16:12:30.507 UTC). Metric đo toàn bộ lệnh `flutter test ... --plain-name=app boots to HomeScreen`, gồm build/install/test overhead, không phải app startup latency thuần. ACK failure/retry integration log được lưu ở `doc/task/evidence/BUG-139-s24u-analytics-ack-recovery.log`.
- Checks/device: link nội bộ của README/matrix/checklist tồn tại; metadata baseline khớp JSON và commit; saved log chứa đúng test và `All tests passed!`; `git diff --check` pass. Không chạy test/app/device mới vì chỉ thay docs. Ảnh tạm tên `ack-retry` thực tế vẫn là trạng thái failure nên không được dùng chứng minh retry success.
- Commit/push: chưa commit/push; task giữ trong `todo`.
