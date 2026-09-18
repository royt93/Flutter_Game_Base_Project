import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/deep_link_command_router.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

int get _realMs => DateTime.now().toUtc().millisecondsSinceEpoch;

final _routes = [
  const DeepLinkRoute(
    commandType: 'level',
    scheme: 'myapp',
    host: 'open',
    pathSegments: ['level', ':id'],
  ),
  const DeepLinkRoute(
    commandType: 'shop',
    scheme: 'myapp',
    host: 'open',
    pathSegments: ['shop'],
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  late StorageService store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = StorageService(await SharedPreferences.getInstance());
    Get.put(store, permanent: true);
  });

  group('parseDeepLink: pure parser', () {
    test('link hợp lệ khớp route "level": map đúng command + params', () {
      final result = parseDeepLink(
        Uri.parse('myapp://open/level/42?campaign=fb'),
        _routes,
      );

      expect(result.isSuccess, isTrue);
      final command = result.value!;
      expect(command.type, 'level');
      expect(command.params, {'id': '42', 'campaign': 'fb'});
    });

    test('link hợp lệ khớp route "shop" (không có path param)', () {
      final result = parseDeepLink(Uri.parse('myapp://open/shop'), _routes);

      expect(result.isSuccess, isTrue);
      expect(result.value!.type, 'shop');
    });

    test('scheme không nằm trong allowlist: reject', () {
      final result = parseDeepLink(
        Uri.parse('evil://open/level/42'),
        _routes,
      );

      expect(result.isSuccess, isFalse);
      expect((result as SdkFailure).kind, SdkErrorKind.validation);
    });

    test('path không khớp route nào: reject', () {
      final result = parseDeepLink(
        Uri.parse('myapp://open/unknown/path'),
        _routes,
      );

      expect(result.isSuccess, isFalse);
    });

    test('URI vượt maxLength: reject an toàn, không parse tiếp', () {
      final hugeQuery = 'x' * 3000;
      final result = parseDeepLink(
        Uri.parse('myapp://open/level/42?q=$hugeQuery'),
        _routes,
        maxLength: 2048,
      );

      expect(result.isSuccess, isFalse);
    });
  });

  group('DeepLinkCommandRouter: link trước app-ready', () {
    test('link đến trước markReady(): queued, handler CHƯA được gọi', () async {
      final router = DeepLinkCommandRouter(routes: _routes);
      var calls = 0;
      router.registerHandler('level', (_) => calls++);

      final result = await router.handleUri(
        Uri.parse('myapp://open/level/1'),
      );

      expect(result.outcome, DeepLinkOutcome.queuedUntilReady);
      expect(calls, 0);
    });

    test('markReady(): drain đúng 1 lần cho link đã queue trước đó', () async {
      final router = DeepLinkCommandRouter(routes: _routes);
      var calls = 0;
      router.registerHandler('level', (_) => calls++);

      await router.handleUri(Uri.parse('myapp://open/level/1'));
      router.markReady();
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
    });

    test('link trùng queue 2 lần trước ready: chỉ xử lý đúng 1 lần khi ready', () async {
      final router = DeepLinkCommandRouter(routes: _routes);
      var calls = 0;
      router.registerHandler('level', (_) => calls++);

      await router.handleUri(Uri.parse('myapp://open/level/1'));
      await router.handleUri(Uri.parse('myapp://open/level/1'));
      router.markReady();
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
    });

    test('markReady() gọi lần 2 không drain lại lần nữa', () async {
      final router = DeepLinkCommandRouter(routes: _routes);
      var calls = 0;
      router.registerHandler('level', (_) => calls++);
      await router.handleUri(Uri.parse('myapp://open/level/1'));

      router.markReady();
      await Future<void>.delayed(Duration.zero);
      router.markReady();
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
    });
  });

  group('DeepLinkCommandRouter: dispatch sau khi ready', () {
    test('link hợp lệ: dispatched, handler nhận đúng command', () async {
      final router = DeepLinkCommandRouter(routes: _routes)..markReady();
      DeepLinkCommand? received;
      router.registerHandler('level', (c) => received = c);

      final result = await router.handleUri(
        Uri.parse('myapp://open/level/7'),
      );

      expect(result.outcome, DeepLinkOutcome.dispatched);
      expect(received?.params['id'], '7');
    });

    test('link không khớp route nào: rejected, không handler nào được gọi', () async {
      final router = DeepLinkCommandRouter(routes: _routes)..markReady();
      var calls = 0;
      router.registerHandler('level', (_) => calls++);

      final result = await router.handleUri(Uri.parse('myapp://open/bogus'));

      expect(result.outcome, DeepLinkOutcome.rejected);
      expect(calls, 0);
    });
  });

  group('DeepLinkCommandRouter: duplicate concurrent/relaunch', () {
    test('link trùng trong cooldown: bị bỏ qua, handler chỉ chạy 1 lần', () async {
      final router = DeepLinkCommandRouter(
        routes: _routes,
        dedupeCooldown: const Duration(seconds: 5),
      )..markReady();
      var calls = 0;
      router.registerHandler('level', (_) => calls++);

      final first = await router.handleUri(Uri.parse('myapp://open/level/1'));
      final second = await router.handleUri(
        Uri.parse('myapp://open/level/1'),
      );

      expect(first.outcome, DeepLinkOutcome.dispatched);
      expect(second.outcome, DeepLinkOutcome.duplicateIgnored);
      expect(calls, 1);
    });

    test('link trùng SAU khi hết cooldown: xử lý lại bình thường', () async {
      final router = DeepLinkCommandRouter(
        routes: _routes,
        dedupeCooldown: const Duration(seconds: 5),
      )..markReady();
      var calls = 0;
      router.registerHandler('level', (_) => calls++);

      await router.handleUri(Uri.parse('myapp://open/level/1'));
      store.setInt(StorageKeys.maxMsSeen, _realMs + 6000);
      final second = await router.handleUri(
        Uri.parse('myapp://open/level/1'),
      );

      expect(second.outcome, DeepLinkOutcome.dispatched);
      expect(calls, 2);
    });

    test('2 lệnh gọi đồng thời (không await giữa) cùng 1 link: deterministic, chỉ 1 lần dispatch thật', () async {
      final router = DeepLinkCommandRouter(routes: _routes)..markReady();
      var calls = 0;
      router.registerHandler('level', (_) async {
        calls++;
      });

      final future1 = router.handleUri(Uri.parse('myapp://open/level/1'));
      final future2 = router.handleUri(Uri.parse('myapp://open/level/1'));
      final results = await Future.wait([future1, future2]);

      expect(
        results.map((r) => r.outcome).toList(),
        [DeepLinkOutcome.dispatched, DeepLinkOutcome.duplicateIgnored],
      );
      expect(calls, 1);
    });
  });

  group('DeepLinkCommandRouter: handler throw không mất link khác', () {
    test('1 handler throw: handler khác CÙNG command vẫn chạy, có diagnostic', () async {
      final router = DeepLinkCommandRouter(routes: _routes)..markReady();
      var secondRan = false;
      router.registerHandler('level', (_) => throw StateError('boom'), priority: 10);
      router.registerHandler('level', (_) => secondRan = true, priority: 0);

      final result = await router.handleUri(
        Uri.parse('myapp://open/level/1'),
      );

      expect(secondRan, isTrue);
      expect(result.handlerResults, hasLength(2));
      expect(result.handlerResults[0].succeeded, isFalse);
      expect(result.handlerResults[0].error, isA<StateError>());
      expect(result.handlerResults[1].succeeded, isTrue);
    });

    test('handler của command A throw không ảnh hưởng command B khác', () async {
      final router = DeepLinkCommandRouter(routes: _routes)..markReady();
      var shopCalled = false;
      router.registerHandler('level', (_) => throw StateError('boom'));
      router.registerHandler('shop', (_) => shopCalled = true);

      await router.handleUri(Uri.parse('myapp://open/level/1'));
      final shopResult = await router.handleUri(Uri.parse('myapp://open/shop'));

      expect(shopCalled, isTrue);
      expect(shopResult.outcome, DeepLinkOutcome.dispatched);
    });

    test('priority cao chạy trước priority thấp', () async {
      final router = DeepLinkCommandRouter(routes: _routes)..markReady();
      final order = <String>[];
      router.registerHandler('level', (_) => order.add('low'), priority: 0);
      router.registerHandler('level', (_) => order.add('high'), priority: 10);

      await router.handleUri(Uri.parse('myapp://open/level/1'));

      expect(order, ['high', 'low']);
    });
  });
}
