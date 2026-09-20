import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/analytics_provider.dart';
import 'package:roy_casual_kit/core/sdk_event_schema_registry.dart';

class _RecordingProvider implements AnalyticsProvider {
  final calls = <(String, Map<String, Object?>?)>[];

  @override
  void logEvent(String name, [Map<String, Object?>? params]) {
    calls.add((name, params));
  }
}

class _ThrowingProvider implements AnalyticsProvider {
  @override
  void logEvent(String name, [Map<String, Object?>? params]) {
    throw Exception('network down');
  }
}

void main() {
  group('EventSchema: validate cấu hình ngay khi tạo', () {
    test('param vừa required vừa pii -> throw ArgumentError ngay khi tạo schema', () {
      expect(
        () => EventSchema(
          name: 'x',
          version: 1,
          params: {'userId': const EventParamSchema(type: EventParamType.string, required: true, pii: true)},
        ),
        throwsArgumentError,
      );
    });
  });

  group('validate: event sai tên', () {
    test('tên event chưa đăng ký -> reject, sanitizedParams rỗng', () {
      final registry = SdkEventSchemaRegistry();
      final result = registry.validate('unknown_event', {'a': 1});

      expect(result.accepted, isFalse);
      expect(result.sanitizedParams, isEmpty);
      expect(result.violations.single, contains('unknown event name'));
    });
  });

  group('validate: type/required', () {
    late SdkEventSchemaRegistry registry;

    setUp(() {
      registry = SdkEventSchemaRegistry();
      registry.register(
        EventSchema(
          name: 'level_complete',
          version: 1,
          params: {
            'level': const EventParamSchema(type: EventParamType.int, required: true),
            'score': const EventParamSchema(type: EventParamType.int),
          },
        ),
      );
    });

    test('đủ field đúng type -> accept, sanitizedParams đúng', () {
      final result = registry.validate('level_complete', {'level': 3, 'score': 900});
      expect(result.accepted, isTrue);
      expect(result.sanitizedParams, {'level': 3, 'score': 900});
      expect(result.violations, isEmpty);
    });

    test('thiếu param required -> reject', () {
      final result = registry.validate('level_complete', {'score': 900});
      expect(result.accepted, isFalse);
      expect(result.violations.single, contains('thiếu param bắt buộc "level"'));
    });

    test('required sai type -> reject', () {
      final result = registry.validate('level_complete', {'level': 'ba', 'score': 900});
      expect(result.accepted, isFalse);
      expect(result.violations.single, contains('level'));
    });

    test('optional sai type -> KHÔNG reject cả event, chỉ drop field đó', () {
      final result = registry.validate('level_complete', {'level': 3, 'score': 'not a number'});
      expect(result.accepted, isTrue);
      expect(result.sanitizedParams, {'level': 3});
      expect(result.violations.single, contains('score'));
    });

    test('params null -> coi như {} (level thiếu -> reject)', () {
      final result = registry.validate('level_complete', null);
      expect(result.accepted, isFalse);
    });
  });

  group('PHÁT HIỆN THẬT: PII luôn bị redact bất kể policy field khác', () {
    test('param pii có mặt -> bị drop khỏi sanitizedParams, event vẫn accept nếu không có lỗi khác', () {
      final registry = SdkEventSchemaRegistry();
      registry.register(
        EventSchema(
          name: 'purchase',
          version: 1,
          params: {
            'sku': const EventParamSchema(type: EventParamType.string, required: true),
            'email': const EventParamSchema(type: EventParamType.string, pii: true),
          },
        ),
      );

      final result = registry.validate('purchase', {'sku': 'gem_100', 'email': 'a@b.com'});

      expect(result.accepted, isTrue);
      expect(result.sanitizedParams.containsKey('email'), isFalse);
      expect(result.sanitizedParams['sku'], 'gem_100');
      expect(result.violations.single, contains('email'));
      expect(result.violations.single, contains('pii'));
    });

    test('param pii không có mặt -> không có violation thừa (không báo redact cái không tồn tại)', () {
      final registry = SdkEventSchemaRegistry();
      registry.register(
        EventSchema(
          name: 'purchase',
          version: 1,
          params: {
            'sku': const EventParamSchema(type: EventParamType.string, required: true),
            'email': const EventParamSchema(type: EventParamType.string, pii: true),
          },
        ),
      );

      final result = registry.validate('purchase', {'sku': 'gem_100'});
      expect(result.accepted, isTrue);
      expect(result.violations, isEmpty);
    });
  });

  group('unknown field policy', () {
    test('policy drop (mặc định): field lạ bị âm thầm bỏ, event vẫn accept', () {
      final registry = SdkEventSchemaRegistry();
      registry.register(
        EventSchema(
          name: 'tap',
          version: 1,
          params: {'x': const EventParamSchema(type: EventParamType.int)},
        ),
      );

      final result = registry.validate('tap', {'x': 1, 'debugNoise': 'ignore me'});
      expect(result.accepted, isTrue);
      expect(result.sanitizedParams.containsKey('debugNoise'), isFalse);
      expect(result.violations, isEmpty, reason: 'drop policy không cần báo violation cho field bị bỏ có chủ đích');
    });

    test('policy reject: field lạ làm reject toàn bộ event', () {
      final registry = SdkEventSchemaRegistry();
      registry.register(
        EventSchema(
          name: 'strict_event',
          version: 1,
          params: {'x': const EventParamSchema(type: EventParamType.int)},
          unknownFieldPolicy: UnknownFieldPolicy.reject,
        ),
      );

      final result = registry.validate('strict_event', {'x': 1, 'extra': 'field'});
      expect(result.accepted, isFalse);
      expect(result.violations.single, contains('extra'));
    });
  });

  group('migrate: schema version migration cho client cũ', () {
    test('client cũ gửi key cũ -> migrate đổi sang key mới trước khi validate', () {
      final registry = SdkEventSchemaRegistry();
      registry.register(
        EventSchema(
          name: 'level_complete',
          version: 2,
          params: {'level': const EventParamSchema(type: EventParamType.int, required: true)},
          migrate: (raw) {
            if (raw.containsKey('lvl') && !raw.containsKey('level')) {
              return {...raw, 'level': raw['lvl']}..remove('lvl');
            }
            return raw;
          },
        ),
      );

      final result = registry.validate('level_complete', {'lvl': 5});
      expect(result.accepted, isTrue);
      expect(result.sanitizedParams, {'level': 5});
    });

    test('không có migrate -> dùng nguyên params như cũ', () {
      final registry = SdkEventSchemaRegistry();
      registry.register(
        EventSchema(
          name: 'simple',
          version: 1,
          params: {'a': const EventParamSchema(type: EventParamType.int)},
        ),
      );
      final result = registry.validate('simple', {'a': 1});
      expect(result.sanitizedParams, {'a': 1});
    });
  });

  group('audit log', () {
    test('mỗi lần validate ghi thêm 1 record, kể cả reject', () {
      final registry = SdkEventSchemaRegistry();
      registry.validate('unknown', {});
      registry.validate('unknown', {});
      expect(registry.auditLog, hasLength(2));
      expect(registry.auditLog.every((r) => !r.accepted), isTrue);
    });

    test('bounded, không phình vô hạn', () {
      final registry = SdkEventSchemaRegistry();
      for (var i = 0; i < 250; i++) {
        registry.validate('unknown', {});
      }
      expect(registry.auditLog.length, lessThanOrEqualTo(200));
    });
  });

  group('SchemaValidatedAnalyticsProvider: forward đúng, không crash gameplay', () {
    test('event hợp lệ -> forward sanitizedParams (không phải raw) tới provider thật', () {
      final registry = SdkEventSchemaRegistry();
      registry.register(
        EventSchema(
          name: 'purchase',
          version: 1,
          params: {
            'sku': const EventParamSchema(type: EventParamType.string, required: true),
            'email': const EventParamSchema(type: EventParamType.string, pii: true),
          },
        ),
      );
      final inner = _RecordingProvider();
      final provider = SchemaValidatedAnalyticsProvider(inner, registry);

      provider.logEvent('purchase', {'sku': 'gem_100', 'email': 'leak@me.com'});

      expect(inner.calls, hasLength(1));
      expect(inner.calls.single.$2, {'sku': 'gem_100'});
    });

    test('event bị reject -> KHÔNG forward gì tới provider thật', () {
      final registry = SdkEventSchemaRegistry();
      final inner = _RecordingProvider();
      final provider = SchemaValidatedAnalyticsProvider(inner, registry);

      provider.logEvent('never_registered', {'a': 1});

      expect(inner.calls, isEmpty);
    });

    test('PHÁT HIỆN THẬT: provider thật throw -> không văng ra ngoài, gameplay code không crash', () {
      final registry = SdkEventSchemaRegistry();
      registry.register(EventSchema(name: 'tap', version: 1, params: const {}));
      final provider = SchemaValidatedAnalyticsProvider(_ThrowingProvider(), registry);

      expect(() => provider.logEvent('tap', {}), returnsNormally);
    });
  });

  group('eventSchemaAuditHealthCollector', () {
    test('chưa có event nào -> totalEvents 0', () async {
      final registry = SdkEventSchemaRegistry();
      final spec = eventSchemaAuditHealthCollector(registry);
      final result = await spec.collect();
      expect(result['totalEvents'], 0);
      expect(result['rejectedCount'], 0);
    });

    test('có event reject -> đúng count và lý do lần reject gần nhất', () async {
      final registry = SdkEventSchemaRegistry();
      registry.validate('a', {});
      registry.validate('b', {});
      final spec = eventSchemaAuditHealthCollector(registry);
      final result = await spec.collect();
      expect(result['totalEvents'], 2);
      expect(result['rejectedCount'], 2);
      expect(result['lastRejectedReasons'], isNotEmpty);
    });

    test('allowedKeys chỉ đúng 3 field, không leak nội dung params thô ra ngoài', () {
      final registry = SdkEventSchemaRegistry();
      final spec = eventSchemaAuditHealthCollector(registry);
      expect(spec.allowedKeys, {'totalEvents', 'rejectedCount', 'lastRejectedReasons'});
    });
  });
}
