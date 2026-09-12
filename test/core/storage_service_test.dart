import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StorageService', () {
    late StorageService store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = StorageService(await SharedPreferences.getInstance());
    });

    test('getInt/getBool trả về def khi chưa có key', () {
      expect(store.getInt('missing'), 0);
      expect(store.getInt('missing', def: 7), 7);
      expect(store.getBool('missing'), false);
      expect(store.getBool('missing', def: true), true);
      expect(store.getString('missing'), isNull);
    });

    test('setInt/setBool/setString rồi đọc lại đúng giá trị', () async {
      await store.setInt('k_int', 42);
      await store.setBool('k_bool', true);
      await store.setString('k_str', 'hello');

      expect(store.getInt('k_int'), 42);
      expect(store.getBool('k_bool'), true);
      expect(store.getString('k_str'), 'hello');
    });

    test('remove xoá key, đọc lại trả về def', () async {
      await store.setInt('k_int', 42);
      await store.remove('k_int');
      expect(store.getInt('k_int'), 0);
    });

    test('StorageKeys giữ 3 hằng số cơ bản, key khác nhau', () {
      expect(StorageKeys.localeCode, isNot(StorageKeys.audioMuted));
      expect(StorageKeys.audioMuted, isNot(StorageKeys.themeDark));
      expect(StorageKeys.localeCode, isNot(StorageKeys.themeDark));
      expect(StorageKeys.colorBlindSafe, isNot(StorageKeys.themeDark));
    });

    test('colorBlindSafe persists as a boolean setting', () async {
      await store.setBool(StorageKeys.colorBlindSafe, true);
      expect(store.getBool(StorageKeys.colorBlindSafe), isTrue);
    });

    test('getDouble trả về def khi chưa có key', () {
      expect(store.getDouble('missing'), 0.0);
      expect(store.getDouble('missing', def: 0.5), 0.5);
    });

    test('setDouble rồi đọc lại đúng giá trị', () async {
      await store.setDouble('k_double', 0.4);
      expect(store.getDouble('k_double'), 0.4);
    });

    test('setBool persist qua StorageKeys.audioMuted', () async {
      expect(store.getBool(StorageKeys.audioMuted, def: false), false);
      await store.setBool(StorageKeys.audioMuted, true);
      expect(store.getBool(StorageKeys.audioMuted, def: false), true);
    });

    test('exportAll trả đúng toàn bộ key/giá trị đã set', () async {
      await store.setInt('k_int', 42);
      await store.setBool('k_bool', true);
      await store.setDouble('k_double', 0.5);
      await store.setString('k_str', 'hello');

      final dump = store.exportAll();
      expect(dump['k_int'], 42);
      expect(dump['k_bool'], true);
      expect(dump['k_double'], 0.5);
      expect(dump['k_str'], 'hello');
    });

    test('importAll ghi đè storage từ map thủ công', () async {
      await store.setString('stale_key', 'must disappear');
      await store.importAll({
        'k_int': 7,
        'k_bool': true,
        'k_double': 1.5,
        'k_str': 'world',
      });

      expect(store.getInt('k_int'), 7);
      expect(store.getBool('k_bool'), true);
      expect(store.getDouble('k_double'), 1.5);
      expect(store.getString('k_str'), 'world');
      expect(store.getString('stale_key'), isNull);
    });

    test('importAll fallback xoá key cũ trước khi import', () async {
      final fallback = StorageService(null);
      await fallback.setString('stale_key', 'old');
      await fallback.importAll({'fresh_key': 'new'});

      expect(fallback.getString('stale_key'), isNull);
      expect(fallback.getString('fresh_key'), 'new');
    });

    test(
      'importAll reject value không hỗ trợ mà không làm mất dữ liệu',
      () async {
        await store.setString('existing_key', 'keep');

        await expectLater(
          store.importAll({
            'bad_key': <Object>[1, 2],
          }),
          throwsA(isA<FormatException>()),
        );

        expect(store.getString('existing_key'), 'keep');
        expect(store.getString('bad_key'), isNull);
      },
    );

    test('importAll reject null mà không xoá storage hiện tại', () async {
      await store.setString('existing_key', 'keep');

      await expectLater(
        store.importAll({'null_key': null}),
        throwsA(isA<FormatException>()),
      );

      expect(store.getString('existing_key'), 'keep');
    });

    test('round-trip đầy đủ: export → import vào StorageService mới', () async {
      await store.setString(StorageKeys.localeCode, 'vi');
      await store.setBool(StorageKeys.audioMuted, true);
      await store.setBool(StorageKeys.themeDark, true);

      final dump = store.exportAll();

      SharedPreferences.setMockInitialValues({});
      final fresh = StorageService(await SharedPreferences.getInstance());
      await fresh.importAll(dump);

      expect(fresh.getString(StorageKeys.localeCode), 'vi');
      expect(fresh.getBool(StorageKeys.audioMuted), true);
      expect(fresh.getBool(StorageKeys.themeDark), true);
    });

    group('setIntBuffered/setStringBuffered/flush (BUG-16)', () {
      test('buffered read ưu tiên hơn giá trị đã ghi disk', () async {
        await store.setIntBuffered('k_int', 1);
        expect(store.getInt('k_int'), 1);
        expect(store.getInt('k_int', def: 99), 1);
      });

      test(
        'flush() ghi đúng giá trị buffered xuống disk và xoá khỏi buffer',
        () async {
          await store.setIntBuffered('k_int', 5);
          await store.setStringBuffered('k_str', 'hi');

          await store.flush();

          expect(store.getInt('k_int'), 5);
          expect(store.getString('k_str'), 'hi');
          // Sau flush, đọc lại không còn phụ thuộc buffer (export chỉ có nguồn
          // duy nhất là disk cho các key này) — kiểm tra qua exportAll để chắc
          // chắn giá trị nằm trên disk thật, không phải còn kẹt ở _buffer.
          expect(store.exportAll()['k_int'], 5);
          expect(store.exportAll()['k_str'], 'hi');
        },
      );

      test('flush() trên buffer rỗng không làm gì, không throw', () async {
        await store.flush();
        expect(store.exportAll(), isEmpty);
      });

      test('BUG-16: giá trị buffered mới cho key B (chưa được flush xử lý) '
          'không bị mất khi key A (xử lý trước B) vẫn đang ghi đĩa', () async {
        // 2 key trong cùng 1 batch flush — 'a' đứng trước 'b' theo thứ tự
        // insertion (Map giữ thứ tự chèn), nên flush() xử lý 'a' trước.
        await store.setIntBuffered('a', 100);
        await store.setIntBuffered('b', 1);

        // Bắt đầu flush nhưng KHÔNG await ngay — flush() chạy đồng bộ tới
        // khi gặp await đầu tiên (bên trong _writeDirect cho key 'a') rồi
        // treo lại ở đó, trả quyền điều khiển về đây.
        final flushFuture = store.flush();

        // Ngay lúc key 'a' đang "chờ ghi đĩa" (theo đúng nghĩa async, dù
        // mock SharedPreferences resolve rất nhanh) và vòng lặp CHƯA xử lý
        // tới key 'b', 1 giá trị buffered MỚI cho 'b' được set. Đây chính
        // là race BUG-16 mô tả: nếu flush() dùng lại `setInt` công khai
        // (tự ý xoá `_buffer[key]` trước khi ghi), giá trị mới này sẽ bị
        // xoá nhầm khi loop xử lý tới 'b' bằng snapshot CŨ.
        await store.setIntBuffered('b', 2);

        await flushFuture;

        expect(
          store.getInt('b'),
          2,
          reason:
              'Giá trị buffered mới (2) phải thắng — không bị flush() ghi '
              'đè bằng snapshot cũ (1) đã chụp trước khi giá trị mới tới.',
        );
        expect(store.getInt('a'), 100);
      });

      test(
        'BUG-16: nếu không có write mới xen vào, flush() vẫn xoá đúng buffer '
        'cho mọi key trong batch (không để sót giá trị cũ mãi mãi trong buffer)',
        () async {
          await store.setIntBuffered('a', 1);
          await store.setIntBuffered('b', 2);

          await store.flush();

          // Đọc trực tiếp exportAll (nguồn disk) khớp đúng — không còn phụ
          // thuộc buffer sau khi đã flush xong hoàn toàn.
          expect(store.exportAll()['a'], 1);
          expect(store.exportAll()['b'], 2);
        },
      );
    });
  });
}
