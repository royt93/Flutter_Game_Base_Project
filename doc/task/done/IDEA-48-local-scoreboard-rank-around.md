---
id: IDEA-48
title: "LocalScoreboardService: cửa sổ xếp hạng quanh 1 người chơi (rank-around window)"
type: idea
priority: medium
effort: S
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/core/local_scoreboard_service.dart`)
---

## Vị trí
Mở rộng — `lib/core/local_scoreboard_service.dart` (`LocalScoreboardService`, IDEA-30).

## Hiện trạng
`LocalScoreboardService` hiện chỉ có `topN(n)` — luôn trả về từ hạng 1 trở xuống. Không có cách nào lấy "hạng của chính người chơi kèm vài người xung quanh" (ví dụ: hạng 47-52, "bạn đang ở hạng 50") — đây là UX kinh điển của mọi bảng xếp hạng casual game khi người chơi không nằm trong top N. `LeaderboardEntry` (widget `LeaderboardList`) đã có sẵn field `highlighted` đúng để tô đậm dòng của người chơi, nhưng không có API service nào tạo ra đúng tập dữ liệu đó.

## Vì sao cần / Hậu quả
Không có tính năng này, 1 game dùng `LocalScoreboardService` muốn hiện "vị trí của bạn" phải tự lặp qua toàn bộ danh sách + tự tính offset — dễ sai (đặc biệt phần tie-break theo `sequence` đã có logic riêng trong service, lặp lại ở tầng gọi dễ lệch).

## Đề xuất
Thêm 1 method mới, ví dụ `List<LeaderboardEntry> entriesAround(String playerLabel, {int radius = 2})` — trả về tối đa `radius` dòng phía trên + chính dòng của lần submit MỚI NHẤT khớp `playerLabel` (nếu có nhiều dòng cùng tên, lấy dòng có `sequence` lớn nhất — tức lần submit gần nhất) + `radius` dòng phía dưới, theo đúng thứ tự đã sort hiện có; đánh dấu đúng dòng của `playerLabel` bằng `highlighted: true`. Trả về danh sách rỗng nếu không tìm thấy `playerLabel` nào. Không cần thay đổi `topN` hiện có.

## Acceptance criteria
- [x] `entriesAround` trả về đúng tối đa `radius` dòng mỗi bên + dòng của người chơi, đúng thứ tự rank hiện tại.
- [x] Dòng của `playerLabel` được đánh dấu `highlighted: true`; các dòng khác `highlighted: false`.
- [x] Người chơi ở hạng 1 hoặc cuối bảng: không lỗi khi không đủ dòng ở 1 phía (trả về ít hơn 2*radius+1 dòng, không throw, không index out of range).
- [x] `playerLabel` không tồn tại trong bảng: trả về danh sách rỗng, không throw.
- [x] Nhiều dòng cùng tên `playerLabel` (submit nhiều lần): dùng đúng dòng có `sequence` lớn nhất (lần submit gần nhất).
- [x] `radius <= 0` hoặc rỗng: xử lý hợp lý, không throw (ví dụ trả về đúng 1 dòng của chính người chơi khi `radius == 0`).
- [x] Test: unit test đầy đủ mọi case trên.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root (không cần đụng `example/` nếu không demo — nhưng nếu thêm demo thì phải sạch cả 2 nơi).
- [x] Không có animation mới cần thiết (đây là thay đổi core service, không phải widget).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-48-local-scoreboard-rank-around.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc `lib/core/local_scoreboard_service.dart` toàn bộ để hiểu đúng cách sort/tie-break/cache hiện có trước khi thêm method mới. Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer, tái dùng đúng `_entries`/`_sortAndTrim` nội bộ đã có thay vì viết lại logic sort riêng).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria — unit test thuần cho `LocalScoreboardService`.
3. Cân nhắc có nên wire method mới vào demo `example/lib/screens/widget_showcase_screen.dart` hay không (không bắt buộc — nếu làm, phải test + device smoke test cho phần đó).
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (và `example/` nếu có đụng tới).
5. Nếu có đụng tới `example/` để demo: smoke test thật trên máy Android thật hiện có (kiểm tra `mobile_list_available_devices` trước, dùng thiết bị đang online — KHÔNG dùng simulator/emulator), chụp screenshot làm bằng chứng, ghi vào `## Quyết định`. Thiết bị có thể đang chia sẻ với peer session khác — kiểm tra `mobile_get_foreground_app`/`ListAgents` trước khi thao tác, dừng ngay nếu phát hiện app khác đang foreground.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk (`git show :path | grep -c '\[x\]'` so với `grep -c '\[x\]'` trên disk), commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `local_scoreboard_service.dart`: `entriesAround`/tương đương chưa tồn tại, `topN` là method public duy nhất hiện có. Effort nhỏ (thuần logic trên danh sách đã sort sẵn trong service), không đụng file nhạy cảm/scope peer.

## Quyết định

Implement `entriesAround(playerLabel, {radius = 2})` — trả về đúng `List<LeaderboardEntry>` như `topN`, tái dùng `_entries` (danh sách đã sắp xếp sẵn) và `LeaderboardEntry`/`fmtNum` có sẵn, không viết thêm cấu trúc dữ liệu mới:

- Tìm index của người chơi bằng cách quét toàn bộ `_entries`, chọn dòng có `sequence` LỚN NHẤT khớp `playerLabel` — xử lý đúng case "submit nhiều lần" (dòng gần nhất mới là dòng đại diện đúng vị trí hiện tại của người chơi).
- `radius` âm được xử lý về hành vi như `0` ngay từ đầu (`safeRadius = radius < 0 ? 0 : radius`), rồi `start`/`end` được `clamp(0, entries.length - 1)` — không index out of range dù người chơi ở đầu/cuối bảng hay bảng rất ngắn.
- `highlighted: i == playerIndex` gắn đúng ngay trong lúc dựng `LeaderboardEntry`, không cần bước map lại riêng.
- Không tìm thấy `playerLabel`: trả về `const <LeaderboardEntry>[]` ngay, không throw.

**Test:** 9 test mới trong `test/core/local_scoreboard_service_test.dart` nhóm "IDEA-48" — cửa sổ đúng radius cả 2 bên + đúng rank, `highlighted` đúng dòng, hạng 1/hạng cuối không đủ dòng 1 phía, playerLabel không tồn tại, nhiều dòng cùng tên dùng đúng sequence mới nhất, `radius == 0`/âm, bảng rỗng — tất cả không throw.

**Demo trong `example/`**: thêm nút "Show rank around me (IDEA-48)" cạnh "Submit random score" trong `LeaderboardList` demo, toggle qua lại giữa `topN(3)` và `entriesAround('You', radius: 1)` — minh hoạ đúng sự khác biệt thực tế giữa 2 API một khi 'You' không còn nằm gọn trong top 3.

**Device smoke test (Pixel 7 Pro, `2B051FDH3006MU`, thiết bị thật)**: submit random score tạo "You" (hạng 3, điểm 3.869) trong bảng 3 người — bấm "Show rank around me" → hiện đúng 2 dòng (hạng 2 Charlie, hạng 3 You — không đủ dòng phía dưới vì 'You' đang ở hạng cuối, đúng case "không đủ dòng 1 phía"), nút đổi đúng label "Show top 3"; bấm lại → quay đúng về top 3 đầy đủ. `adb logcat` lọc `level=Error` trước/sau: không có dòng nào.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1098/1098 pass; `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 51/51 pass (bao gồm 1 widget test mới cho nút toggle).

**Tự chấm điểm: 9.5/10** — đúng mọi acceptance criteria, tái dùng 100% hạ tầng có sẵn (`LeaderboardEntry`, `fmtNum`, `_entries`), xử lý đúng edge case tinh vi nhất (nhiều lần submit cùng tên — chọn đúng sequence mới nhất chứ không phải điểm cao nhất), có bằng chứng device thật cho đúng chính xác trường hợp "hạng cuối, không đủ dòng 1 phía" mà acceptance criteria yêu cầu. Trừ điểm nhỏ vì demo trong `example/` là 1 toggle đơn giản, không dựng thêm UI "you're #N" chuyên biệt hơn (không cần thiết cho phạm vi task).
