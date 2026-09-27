import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BUG-81: records every mutating call so tests can prove exactly which keys
/// `importWithPrefix` touched, and in what order.
class _RecordingStorageService extends StorageService {
  _RecordingStorageService(super.prefs);
  final touched = <String>[];

  @override
  Future<void> setInt(String key, int value) {
    touched.add('set:$key');
    return super.setInt(key, value);
  }

  @override
  Future<void> setBool(String key, bool value) {
    touched.add('set:$key');
    return super.setBool(key, value);
  }

  @override
  Future<void> setDouble(String key, double value) {
    touched.add('set:$key');
    return super.setDouble(key, value);
  }

  @override
  Future<void> setString(String key, String value) {
    touched.add('set:$key');
    return super.setString(key, value);
  }

  @override
  Future<void> remove(String key) {
    touched.add('remove:$key');
    return super.remove(key);
  }
}

/// BUG-81 (post-audit #2): records touched keys AND throws once on a chosen
/// key — proves the ORDER rollback itself writes in, not just its end state.
class _RecordingThrowingStorageService extends StorageService {
  _RecordingThrowingStorageService(super.prefs, this.throwOnKey);
  final String throwOnKey;
  final touched = <String>[];

  @override
  Future<void> setString(String key, String value) {
    touched.add('set:$key');
    if (key == throwOnKey) {
      throw Exception('simulated platform write failure');
    }
    return super.setString(key, value);
  }

  @override
  Future<void> remove(String key) {
    touched.add('remove:$key');
    return super.remove(key);
  }
}

class _ThrowingAfterNStorageService extends StorageService {
  _ThrowingAfterNStorageService(super.prefs, this.throwOnKey);
  final String throwOnKey;

  @override
  Future<void> setString(String key, String value) {
    if (key == throwOnKey) {
      throw Exception('simulated platform write failure');
    }
    return super.setString(key, value);
  }
}

class _RollbackFailingStorageService extends StorageService {
  _RollbackFailingStorageService(super.prefs);
  bool armed = false;

  @override
  Future<void> setString(String key, String value) {
    if (armed && key == 'slot_a_new_fail') {
      throw StateError('original write failure');
    }
    if (armed && key == 'slot_a_old') {
      throw StateError('rollback failure');
    }
    return super.setString(key, value);
  }
}

class _BlockingPrefixStorageService extends StorageService {
  _BlockingPrefixStorageService(super.prefs);
  final firstWriteStarted = Completer<void>();
  final releaseFirstWrite = Completer<void>();
  bool armed = false;
  bool _blocked = false;

  @override
  Future<void> setString(String key, String value) async {
    if (armed && !_blocked && key == 'slot_a_first') {
      _blocked = true;
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    return super.setString(key, value);
  }
}

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

    group('IDEA-55: eraseAll', () {
      test(
        'xoá sạch mọi key hiện có — exportAll() trả về map rỗng sau đó',
        () async {
          await store.setString(StorageKeys.localeCode, 'vi');
          await store.setBool(StorageKeys.audioMuted, true);
          await store.setInt(StorageKeys.energyCount, 5);
          expect(store.exportAll(), isNotEmpty);

          await store.eraseAll();

          expect(store.exportAll(), isEmpty);
        },
      );

      test(
        'sau eraseAll(), đọc lại bất kỳ key nào đều trả về mặc định, không throw',
        () async {
          await store.setString(StorageKeys.localeCode, 'vi');
          await store.setBool(StorageKeys.audioMuted, true);
          await store.setInt(StorageKeys.energyCount, 5);

          await store.eraseAll();

          expect(store.getString(StorageKeys.localeCode), isNull);
          expect(store.getBool(StorageKeys.audioMuted), false);
          expect(store.getInt(StorageKeys.energyCount, def: 3), 3);
        },
      );

      test('xoá cả key đang buffer chưa flush', () async {
        await store.setIntBuffered('buffered_key', 42);
        expect(store.getInt('buffered_key'), 42);

        await store.eraseAll();

        expect(store.getInt('buffered_key'), 0);
        expect(store.exportAll(), isEmpty);
      });

      test('không đổi hành vi importAll/exportAll hiện có', () async {
        await store.setString('k', 'v');
        await store.importAll({'k2': 'v2'});
        expect(store.getString('k'), isNull); // importAll vẫn ghi đè như cũ
        expect(store.getString('k2'), 'v2');
        expect(store.exportAll(), {'k2': 'v2'});
      });
    });

    group('IDEA-56: removeAllWithPrefix', () {
      test(
        'xoá đúng mọi key có prefix, không đụng key khác không có prefix đó',
        () async {
          await store.setString('slot_a_name', 'Alice');
          await store.setInt('slot_a_score', 100);
          await store.setString('slot_b_name', 'Bob');
          await store.setString('unrelated', 'keep me');

          await store.removeAllWithPrefix('slot_a_');

          expect(store.getString('slot_a_name'), isNull);
          expect(store.getInt('slot_a_score', def: -1), -1);
          expect(
            store.getString('slot_b_name'),
            'Bob',
          ); // slot khác không bị đụng
          expect(store.getString('unrelated'), 'keep me');
        },
      );

      test(
        'prefix rỗng throw ArgumentError, không âm thầm xoá sạch toàn bộ storage',
        () async {
          await store.setString('k', 'v');

          expect(() => store.removeAllWithPrefix(''), throwsArgumentError);
          expect(store.getString('k'), 'v'); // không bị xoá
        },
      );

      test('prefix không khớp key nào: no-op an toàn, không throw', () async {
        await store.setString('k', 'v');

        await store.removeAllWithPrefix('no_such_prefix_');

        expect(store.getString('k'), 'v');
      });

      test(
        'BUG-39: không native-rewrite bất kỳ key nào ngoài prefix '
        '(platformWrites không tăng — trước đây đi qua importAll/_replaceAll '
        'sẽ setInt/setString lại MỌI key còn sót, tăng platformWrites theo '
        'đúng số key không liên quan)',
        () async {
          await store.setString('slot_a_name', 'Alice');
          await store.setString('unrelated1', 'x');
          await store.setInt('unrelated2', 42);
          final before = store.platformWrites;

          await store.removeAllWithPrefix('slot_a_');

          expect(store.platformWrites, before);
        },
      );

      test(
        'BUG-39: giá trị buffered (setXBuffered, chưa flush) thuộc prefix '
        'cũng bị xoá; buffered ngoài prefix không bị đụng',
        () async {
          await store.setIntBuffered('slot_a_buffered', 7);
          await store.setStringBuffered('unrelated_buffered', 'keep');

          await store.removeAllWithPrefix('slot_a_');

          expect(store.getInt('slot_a_buffered', def: -1), -1);
          expect(store.getString('unrelated_buffered'), 'keep');
        },
      );

      test(
        'BUG-39: khi SharedPreferences null (fallback in-memory), chỉ xoá '
        'đúng key khớp prefix trong fallback map',
        () async {
          final fallbackStore = StorageService(null);
          await fallbackStore.setString('slot_a_name', 'Alice');
          await fallbackStore.setString('unrelated', 'keep me');

          await fallbackStore.removeAllWithPrefix('slot_a_');

          expect(fallbackStore.getString('slot_a_name'), isNull);
          expect(fallbackStore.getString('unrelated'), 'keep me');
        },
      );
    });

    group('ENH-77: exportWithPrefix/importWithPrefix', () {
      test(
        'exportWithPrefix trả đúng chỉ key có prefix, không lẫn key khác',
        () async {
          await store.setString('slot_a_name', 'Alice');
          await store.setInt('slot_a_score', 100);
          await store.setString('slot_b_name', 'Bob');
          await store.setString('unrelated', 'keep me');

          final dump = store.exportWithPrefix('slot_a_');

          expect(dump, {'slot_a_name': 'Alice', 'slot_a_score': 100});
        },
      );

      test('exportWithPrefix rỗng throw ArgumentError', () {
        expect(() => store.exportWithPrefix(''), throwsArgumentError);
      });

      test('importWithPrefix rỗng throw ArgumentError, không ghi gì', () async {
        await store.setString('k', 'v');

        expect(
          () => store.importWithPrefix('', {'k': 'v2'}),
          throwsArgumentError,
        );
        expect(store.getString('k'), 'v');
      });

      test(
        'importWithPrefix với data có key không thuộc prefix throw ArgumentError, không ghi gì',
        () async {
          await store.setString('slot_a_name', 'Alice');

          expect(
            () => store.importWithPrefix('slot_a_', {'other_key': 'x'}),
            throwsArgumentError,
          );
          expect(store.getString('slot_a_name'), 'Alice');
          expect(store.getString('other_key'), isNull);
        },
      );

      test(
        'importWithPrefix hợp lệ: thay đúng key trong prefix, giữ nguyên key ngoài prefix, xoá key cũ trong prefix không còn trong data mới',
        () async {
          await store.setString('slot_a_name', 'Alice');
          await store.setInt('slot_a_score', 100);
          await store.setString('unrelated', 'keep me');

          await store.importWithPrefix('slot_a_', {
            'slot_a_name': 'Alice renamed',
          });

          expect(store.getString('slot_a_name'), 'Alice renamed');
          expect(store.getInt('slot_a_score', def: -1), -1); // đã bị xoá
          expect(store.getString('unrelated'), 'keep me');
        },
      );

      test(
        'exportWithPrefix rồi importWithPrefix cùng prefix khôi phục đúng y hệt',
        () async {
          await store.setString('slot_a_name', 'Alice');
          await store.setInt('slot_a_score', 100);
          final dump = store.exportWithPrefix('slot_a_');

          await store.removeAllWithPrefix('slot_a_');
          expect(store.getString('slot_a_name'), isNull);

          await store.importWithPrefix('slot_a_', dump);

          expect(store.getString('slot_a_name'), 'Alice');
          expect(store.getInt('slot_a_score', def: -1), 100);
        },
      );

      test(
        'lỗi giữa chừng (value không hỗ trợ) rollback đúng, không half-restore',
        () async {
          await store.setString('slot_a_name', 'Alice');
          await store.setString('unrelated', 'keep me');

          await expectLater(
            store.importWithPrefix('slot_a_', {
              'slot_a_bad': <Object>[1, 2],
            }),
            throwsA(isA<FormatException>()),
          );

          expect(store.getString('slot_a_name'), 'Alice');
          expect(store.getString('unrelated'), 'keep me');
          expect(store.getString('slot_a_bad'), isNull);
        },
      );

      test(
        'BUG-81: platformWrites tăng đúng bằng số key trong data, không phụ '
        'thuộc số key ngoài prefix',
        () async {
          await store.setString('slot_a_name', 'Alice');
          await store.setString('unrelated1', 'a');
          await store.setInt('unrelated2', 1);
          await store.setBool('unrelated3', true);

          final before = store.platformWrites;
          await store.importWithPrefix('slot_a_', {
            'slot_a_name': 'Alice renamed',
          });

          expect(store.platformWrites, before + 1);
        },
      );

      test(
        'BUG-81: blast radius — key ngoài prefix không hề bị set/remove',
        () async {
          final recording = _RecordingStorageService(
            await SharedPreferences.getInstance(),
          );
          await recording.setString('slot_a_name', 'Alice');
          await recording.setInt('slot_a_score', 100);
          await recording.setString('unrelated1', 'a');
          await recording.setInt('unrelated2', 1);
          recording.touched.clear();

          await recording.importWithPrefix('slot_a_', {
            'slot_a_name': 'Alice renamed',
          });

          expect(
            recording.touched.where((t) => t.contains('unrelated')),
            isEmpty,
          );
          expect(recording.touched, contains('set:slot_a_name'));
          expect(recording.touched, contains('remove:slot_a_score'));
        },
      );

      test(
        'BUG-81: set áp dụng trước remove trong cùng 1 lần import',
        () async {
          final recording = _RecordingStorageService(
            await SharedPreferences.getInstance(),
          );
          await recording.setString('slot_a_old', 'stale');
          await recording.setString('slot_a_keep', 'v1');
          recording.touched.clear();

          await recording.importWithPrefix('slot_a_', {
            'slot_a_keep': 'v2',
            'slot_a_new': 'x',
          });

          final lastSet = recording.touched.lastIndexWhere(
            (t) => t.startsWith('set:'),
          );
          final firstRemove = recording.touched.indexWhere(
            (t) => t.startsWith('remove:'),
          );
          expect(firstRemove, greaterThan(lastSet));
        },
      );

      test(
        'BUG-81: round-trip giữ đúng mọi kiểu giá trị',
        () async {
          await store.setString('slot_a_str', 'hi');
          await store.setInt('slot_a_int', 7);
          await store.setBool('slot_a_bool', true);
          await store.setDouble('slot_a_double', 1.5);

          final dump = store.exportWithPrefix('slot_a_');
          await store.removeAllWithPrefix('slot_a_');
          await store.importWithPrefix('slot_a_', dump);

          expect(store.getString('slot_a_str'), 'hi');
          expect(store.getInt('slot_a_int'), 7);
          expect(store.getBool('slot_a_bool'), true);
          expect(store.getDouble('slot_a_double'), 1.5);
        },
      );

      test(
        'BUG-81 audit: platform write throw giữa loop rollback đúng prefix',
        () async {
          final prefs = await SharedPreferences.getInstance();
          final throwing = _ThrowingAfterNStorageService(
            prefs,
            'slot_a_second',
          );
          await throwing.setString('slot_a_first', 'old-first');
          await throwing.setString('slot_a_stale', 'old-stale');
          await throwing.setString('unrelated', 'keep me');

          await expectLater(
            throwing.importWithPrefix('slot_a_', {
              'slot_a_first': 'new-first',
              'slot_a_second': 'new-second',
            }),
            throwsA(isA<Exception>()),
          );

          expect(throwing.getString('slot_a_first'), 'old-first');
          expect(throwing.getString('slot_a_second'), isNull);
          expect(throwing.getString('slot_a_stale'), 'old-stale');
          expect(throwing.getString('unrelated'), 'keep me');
        },
      );

      test(
        'BUG-81 audit: rollback fail vẫn rethrow original write error',
        () async {
          final prefs = await SharedPreferences.getInstance();
          final throwing = _RollbackFailingStorageService(prefs);
          await throwing.setString('slot_a_old', 'old');
          throwing.armed = true;

          Object? caught;
          try {
            await throwing.importWithPrefix('slot_a_', {
              'slot_a_new_ok': 'new',
              'slot_a_new_fail': 'boom',
            });
          } catch (error) {
            caught = error;
          }

          expect(caught, isA<StateError>());
          expect((caught as StateError).message, 'original write failure');
        },
      );

      test(
        'BUG-81 audit: 2 import cùng prefix serialize, không tạo save lai',
        () async {
          final prefs = await SharedPreferences.getInstance();
          final blocking = _BlockingPrefixStorageService(prefs);
          await blocking.setString('slot_a_old', 'old');
          blocking.armed = true;

          final first = blocking.importWithPrefix('slot_a_', {
            'slot_a_first': 'A1',
            'slot_a_second': 'A2',
          });
          await blocking.firstWriteStarted.future;

          // Call thứ 2 đến khi call thứ 1 đang đứng giữa set-loop. Nó phải
          // chờ — không được xen set/remove hoặc dùng snapshot dở dang của A.
          final second = blocking.importWithPrefix('slot_a_', {
            'slot_a_first': 'B1',
            'slot_a_third': 'B3',
          });
          var secondCompletedEarly = false;
          unawaited(second.then((_) => secondCompletedEarly = true));
          await Future<void>.delayed(Duration.zero);
          expect(secondCompletedEarly, isFalse);

          blocking.releaseFirstWrite.complete();
          await first;
          await second;

          // Last invocation wins as one WHOLE replace-scoped operation.
          expect(blocking.getString('slot_a_first'), 'B1');
          expect(blocking.getString('slot_a_second'), isNull);
          expect(blocking.getString('slot_a_third'), 'B3');
        },
      );

      test(
        'BUG-81 audit #2: rollback tự nó cũng set trước remove sau '
        '(crash giữa rollback không được để mất dữ liệu cũ)',
        () async {
          final prefs = await SharedPreferences.getInstance();
          final recording = _RecordingThrowingStorageService(
            prefs,
            'slot_a_fail',
          );
          await recording.setString('slot_a_keep', 'v1');

          await expectLater(
            recording.importWithPrefix('slot_a_', {
              'slot_a_keep': 'v2',
              'slot_a_new': 'x',
              'slot_a_fail': 'boom',
            }),
            throwsA(isA<Exception>()),
          );

          // Rollback restores `slot_a_keep` and removes the newly-added
          // `slot_a_new` — its OWN set must land before its OWN remove, or a
          // kill mid-rollback would leave the prefix with data MISSING
          // (`slot_a_keep` deleted before being restored) instead of merely
          // extra — the exact regression this test locks in.
          final lastSet = recording.touched.lastIndexWhere(
            (t) => t.startsWith('set:'),
          );
          final firstRemove = recording.touched.indexWhere(
            (t) => t.startsWith('remove:'),
          );
          expect(firstRemove, greaterThan(lastSet));

          expect(recording.getString('slot_a_keep'), 'v1');
          expect(recording.getString('slot_a_new'), isNull);
        },
      );
    });
  });

  group(
    // BUG-55: chín-mấy service dùng string literal làm default storageKey
    // thay vì tham chiếu 1 hằng số StorageKeys — vi phạm convention của
    // chính CLAUDE.md. Refactor CƠ HỌC (không đổi giá trị chuỗi thật, chỉ
    // đổi CÁCH tham chiếu) — nếu đổi nhầm giá trị chuỗi, save đã có của
    // người chơi cũ sẽ "biến mất" (đọc nhầm key rỗng). Test này khoá cứng
    // từng giá trị chuỗi ĐÚNG NHƯ TRƯỚC khi refactor.
    'BUG-55: default storageKey constants giữ đúng giá trị chuỗi cũ (không '
    'đổi format save đã có)',
    () {
      test('giá trị từng hằng số khớp đúng literal cũ (không đổi)', () {
        expect(
          StorageKeys.achievementProgressV1,
          'achievement_progress_v1',
        );
        expect(
          StorageKeys.checkpointCoordinatorV1,
          'checkpoint_coordinator_v1',
        );
        expect(StorageKeys.dailyLoginStateV1, 'daily_login_state_v1');
        expect(
          StorageKeys.dailyQuestProgressV1,
          'daily_quest_progress_v1',
        );
        expect(StorageKeys.economyWalletV1, 'economy_wallet_v1');
        expect(StorageKeys.inventoryServiceV1, 'inventory_service_v1');
        expect(StorageKeys.localScoreboardV1, 'local_scoreboard_v1');
        expect(StorageKeys.onboardingSeenV1, 'onboarding_seen_v1');
        expect(StorageKeys.playerProgressionV1, 'player_progression_v1');
        expect(StorageKeys.offlineOutboxV1, 'offline_outbox_v1');
        expect(StorageKeys.purchaseLedgerV1, 'purchase_ledger_v1');
        expect(
          StorageKeys.seasonEventAnchorsV1,
          'season_event_anchors_v1',
        );
        expect(
          StorageKeys.rewardTransactionPipelineV1,
          'reward_transaction_pipeline_v1',
        );
        expect(StorageKeys.saveSlotMetaV1, 'save_slot_meta_v1');
        expect(StorageKeys.saveSlotActiveIdV1, 'save_slot_active_id_v1');
      });

      test('không trùng lặp giá trị với bất kỳ hằng số nào khác', () {
        final values = [
          StorageKeys.achievementProgressV1,
          StorageKeys.checkpointCoordinatorV1,
          StorageKeys.dailyLoginStateV1,
          StorageKeys.dailyQuestProgressV1,
          StorageKeys.economyWalletV1,
          StorageKeys.inventoryServiceV1,
          StorageKeys.localScoreboardV1,
          StorageKeys.onboardingSeenV1,
          StorageKeys.playerProgressionV1,
          StorageKeys.offlineOutboxV1,
          StorageKeys.purchaseLedgerV1,
          StorageKeys.seasonEventAnchorsV1,
          StorageKeys.rewardTransactionPipelineV1,
          StorageKeys.saveSlotMetaV1,
          StorageKeys.saveSlotActiveIdV1,
        ];
        expect(values.toSet().length, values.length);
      });
    },
  );
}
