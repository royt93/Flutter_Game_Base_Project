---
id: FEAT-81
title: "Remote Schema Compiler"
type: feature
layer: liveops/tooling
priority: P1
effort: L
depends_on: [ENH-58, IDEA-37, FEAT-37]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Compile/validate remote content schema thành typed Dart models và migration fixtures.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Schema invalid/signature/version không tạo code hoặc content unsafe.
- [x] Generated model immutable, backward migration có test.
- [x] Asset fallback và generated content cho cùng fixture ra cùng semantic result.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Xây `lib/core/utils/remote_schema_compiler.dart` — thuần Dart, không phụ
thuộc Flutter (chạy `dart run` headless đúng convention FEAT-72/76/78),
gồm 4 mảnh GHÉP tối đa từ primitive đã có, không tự phát minh cơ chế mới:

**"Schema invalid/signature/version không tạo code hoặc content unsafe"**
— `RemoteSchemaDef`'s factory constructor LÀ cổng validate duy nhất: schema
hỏng (version trùng/âm, field/pack name không phải Dart identifier hợp lệ,
1 version rỗng field) không bao giờ tạo ra được instance, nên KHÔNG BƯỚC
NÀO phía sau (codegen, ghép migration, verify fixture) có thể chạy trên
schema hỏng — test 7 case invalid đều throw trước khi chạm bất kỳ logic
nào khác. `verifySignedFixture` tái dùng ĐÚNG 2 gate `RemoteContentPack`
(IDEA-37) đã áp dụng lúc runtime: HMAC qua `save_integrity.dart`'s
`verifyAndStrip`, và từ chối `schemaVersion` mới hơn schema đã compile —
CLI gọi hàm này TRƯỚC khi ghi bất kỳ file nào, nên 1 fixture giả mạo/quá
mới không bao giờ được "bake" vào code sinh ra.

**"Generated model immutable, backward migration có test"** —
`generateModelSource` sinh class `final` field + `const` constructor +
`==`/`hashCode` giá trị (không mutable setter nào). Quan trọng nhất: file
sinh ra **KHÔNG IMPORT GÌ CẢ**, kể cả chính package này — tự viết lại 4
hàm đọc kiểu dung sai (`_asString`/`_asInt`/`_asDouble`/`_asBool`, cùng
tinh thần `safe_json.dart` nhưng inline) thay vì import, nên nâng cấp
`roy_casual_kit` sau này KHÔNG BAO GIỜ làm hỏng 1 file đã sinh trước đó —
đây chính là "compatibility policy" mà acceptance criteria đòi. Migration
KHÔNG tự viết logic mới: `buildMigrationRegistry` chỉ ghép version list
của schema vào `SaveMigrationRegistry` có sẵn (FEAT-37) — validate chuỗi
hop vẫn do chính `SaveMigrationRegistry` đảm nhiệm, hàm này chỉ thêm 1 lớp
guard riêng (thiếu migrate function cho 1 hop → throw ngay, rõ ràng hơn để
lộ lỗi xuống tận `SaveMigrationException` mơ hồ hơn). Test có "backward
migration": schema 2 và 3 version, migrate v1→v2 áp dụng đúng qua registry
đã ghép, thiếu hop giữa vẫn bị bắt.

**"Asset fallback và generated content cho cùng fixture ra cùng semantic
result"** — làm THẬT bằng cách sinh model THẬT vào `example/lib/generated/shop_catalog_content.g.dart`
(từ `example/remote_schemas/shop_catalog.schema.json`, chạy 1 lần bằng
chính CLI này, commit lại — đúng convention "consumer/example
integration" của sprint slice) rồi viết
`example/test/shop_catalog_content_cross_check_test.dart`: decode CÙNG 1
fixture JSON qua `RemoteContentPack<ShopCatalogContent>` (đường "asset
fallback", dùng đúng `_FakeAssetBundle` convention có sẵn ở
`test/core/remote_content_pack_test.dart`) và trực tiếp
`ShopCatalogContent.fromJson` (đường "generated content"), assert 2 kết
quả bằng nhau qua `==` — chứng minh model sinh ra tương thích thật với
runtime path hiện có, không chỉ đúng trên giấy.

**Bằng chứng code sinh ra THẬT SỰ compile/chạy được** (không chỉ khớp
string mẫu): `test/tool/remote_schema_compiler_test.dart` chạy CLI thật
qua subprocess, rồi viết 1 harness `.dart` import TRỰC TIẾP file `.g.dart`
vừa sinh (relative import, không cần package context vì file không import
gì) và `dart run` harness đó thật — in `true`/JSON đúng ra stdout.

Verify:
- `flutter test test/core/utils/remote_schema_compiler_test.dart`:
  18/18 pass (validate schema, generate model, ghép migration, verify
  fixture chữ ký/version).
- `flutter test test/tool/remote_schema_compiler_test.dart`: 4/4 pass
  (schema hợp lệ → sinh + `dart run` harness thật; schema hỏng → exit 1,
  không ghi file nào; fixture sai secret → reject, không sinh file;
  fixture đúng → verify OK rồi mới sinh).
- `flutter test example/test/shop_catalog_content_cross_check_test.dart`:
  pass — cross-check semantic thật.
- `flutter analyze` root + `example/`: sạch.
- `flutter test --exclude-tags slow` root: 2010/2010 pass.
- `flutter test --exclude-tags slow` example/: 98/98 pass.
- `dart run tool/api_compatibility.dart snapshot` rồi `check` →
  `unchanged` (đã export `remote_schema_compiler.dart`, CHANGELOG.md có
  mục 0.2.0 tương ứng).
- `dart pub publish --dry-run`: chỉ cảnh báo git chưa commit.

**Không có UI mới trong package** — `example/test/`'s cross-check test là
1 `test()` thuần (không `testWidgets`), không animation/accessibility nào
để xét; tiêu chí đó vacuously đúng, cùng cách FEAT-84/83 đã đánh dấu cho
task không đụng UI.

Tự chấm: 9.5/10. Điểm cao vì compiler không tự phát minh bất kỳ cơ chế an
toàn nào mới — mọi gate (signature, version-reject-tương-lai, migration
chain) đều GHÉP nguyên xi từ 2 primitive đã kiểm chứng trước đó
(`save_integrity.dart`, `SaveMigrationRegistry`), và "model sinh ra tương
thích với runtime path" được chứng minh bằng 1 file thật commit vào
`example/` + test cross-check thật, không phải khẳng định suông. Trừ 0.5
vì migration logic cho từng hop (`stepMigrations`) vẫn phải tự tay viết —
đây là giới hạn cố ý (schema khai báo không đủ để tự sinh field-transform
an toàn), đã ghi rõ trong doc-comment, nhưng vẫn là phần compiler "chưa
tự động hoá hoàn toàn".

