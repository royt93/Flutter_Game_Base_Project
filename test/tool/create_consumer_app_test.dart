import 'package:flutter_test/flutter_test.dart';

import '../../tool/create_consumer_app.dart';

void main() {
  group('isValidAppName', () {
    test('snake_case chữ thường hợp lệ', () {
      expect(isValidAppName('my_game'), isTrue);
      expect(isValidAppName('a'), isTrue);
      expect(isValidAppName('game2'), isTrue);
    });

    test('rỗng, hoa, bắt đầu bằng số, có ký tự lạ -> false', () {
      expect(isValidAppName(''), isFalse);
      expect(isValidAppName('MyGame'), isFalse);
      expect(isValidAppName('2game'), isFalse);
      expect(isValidAppName('my-game'), isFalse);
      expect(isValidAppName('my game'), isFalse);
    });

    test('từ khoá Dart reserved -> false', () {
      expect(isValidAppName('class'), isFalse);
      expect(isValidAppName('import'), isFalse);
      expect(isValidAppName('void'), isFalse);
    });

    test('quá dài (>64 ký tự) -> false', () {
      expect(isValidAppName('a' * 65), isFalse);
      expect(isValidAppName('a' * 64), isTrue);
    });
  });

  group('isValidOrg', () {
    test('reverse-domain hợp lệ', () {
      expect(isValidOrg('com.example'), isTrue);
      expect(isValidOrg('com.example.studio'), isTrue);
    });

    test('thiếu dấu chấm, segment rỗng, ký tự lạ -> false', () {
      expect(isValidOrg('com'), isFalse);
      expect(isValidOrg('com.'), isFalse);
      expect(isValidOrg('com.example-studio'), isFalse);
      expect(isValidOrg(''), isFalse);
    });
  });

  group('kitDependencyBlock', () {
    test('không truyền kitPath -> dùng version hosted', () {
      expect(
        kitDependencyBlock(kitVersion: '^0.2.0'),
        '  roy_casual_kit: ^0.2.0\n  get: ^4.7.3\n  flame: ^1.35.1\n  shared_preferences: ^2.5.5\n',
      );
    });

    test('truyền kitPath -> dùng path dependency', () {
      expect(
        kitDependencyBlock(kitPath: '../..'),
        '  roy_casual_kit:\n    path: ../..\n  get: ^4.7.3\n  flame: ^1.35.1\n  shared_preferences: ^2.5.5\n',
      );
    });

    test(
      'luôn kèm get/flame/shared_preferences làm direct dependency (tránh depend_on_referenced_packages)',
      () {
        expect(kitDependencyBlock(), contains('get: ^4.7.3'));
        expect(kitDependencyBlock(), contains('flame: ^1.35.1'));
        expect(kitDependencyBlock(), contains('shared_preferences: ^2.5.5'));
      },
    );
  });

  group('patchPubspecWithDependency', () {
    test('chèn đúng ngay sau dòng "dependencies:" đầu tiên', () {
      const pubspec =
          'name: my_game\nversion: 1.0.0\n\ndependencies:\n  flutter:\n    sdk: flutter\n';
      final patched = patchPubspecWithDependency(
        pubspec,
        '  roy_casual_kit: ^0.2.0',
      );
      final lines = patched.split('\n');
      final depIndex = lines.indexOf('dependencies:');
      expect(lines[depIndex + 1], '  roy_casual_kit: ^0.2.0');
    });

    test('không có "dependencies:" -> throw ArgumentError', () {
      expect(
        () =>
            patchPubspecWithDependency('name: x\n', '  roy_casual_kit: ^0.2.0'),
        throwsArgumentError,
      );
    });
  });

  group('patchAndroidBuildGradleForDesugaring', () {
    const freshBuildGradle = '''
android {
    namespace = "com.example.x"
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
''';

    test('bật isCoreLibraryDesugaringEnabled ngay sau targetCompatibility', () {
      final patched = patchAndroidBuildGradleForDesugaring(freshBuildGradle);
      expect(patched, contains('isCoreLibraryDesugaringEnabled = true'));
      final lines = patched.split('\n');
      final targetIndex = lines.indexWhere(
        (l) => l.contains('targetCompatibility'),
      );
      expect(
        lines[targetIndex + 1],
        contains('isCoreLibraryDesugaringEnabled = true'),
      );
    });

    test('thêm dependencies block với coreLibraryDesugaring đúng version', () {
      final patched = patchAndroidBuildGradleForDesugaring(freshBuildGradle);
      expect(
        patched,
        contains(
          'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',
        ),
      );
    });

    test(
      'không có targetCompatibility -> throw ArgumentError, không âm thầm bỏ qua',
      () {
        expect(
          () => patchAndroidBuildGradleForDesugaring('android {}\n'),
          throwsArgumentError,
        );
      },
    );
  });

  group('template content: sinh ra Dart hợp lệ về mặt cấu trúc cơ bản', () {
    test(
      'mainDartTemplate: class name PascalCase đúng từ snake_case, không còn khoảng trắng lạ',
      () {
        final content = mainDartTemplate(appName: 'my_cool_game');
        expect(
          content,
          contains('class MyCoolGameApp extends StatelessWidget'),
        );
        expect(content, contains('const MyCoolGameApp({super.key});'));
        expect(content, contains('runApp(const MyCoolGameApp());'));
        expect(content, isNot(contains('App App')));
      },
    );

    test('mainDartTemplate: có gọi RoyCasualKit.initialize', () {
      final content = mainDartTemplate(appName: 'a');
      expect(content, contains('RoyCasualKit.initialize'));
      expect(content, contains('RoyCasualKitModule.storage'));
    });

    test('smokeTestTemplate: import đúng theo tên package/app truyền vào', () {
      final content = smokeTestTemplate(appName: 'my_cool_game');
      expect(
        content,
        contains("import 'package:my_cool_game/screens/home_screen.dart';"),
      );
    });

    test('gameDemoScreenTemplate: dùng đúng RoyGame/GameWidget của kit', () {
      final content = gameDemoScreenTemplate();
      expect(content, contains('RoyGame()'));
      expect(content, contains('GameWidget'));
    });

    test('ciWorkflowTemplate: có step analyze và test', () {
      final content = ciWorkflowTemplate();
      expect(content, contains('flutter analyze'));
      expect(content, contains('flutter test'));
    });
  });

  group('readTemplateVersion', () {
    test('không có marker file -> null', () {
      expect(
        readTemplateVersion(
          '/tmp/definitely_does_not_exist_${DateTime.now().microsecondsSinceEpoch}',
        ),
        isNull,
      );
    });
  });

  group('generate: validate trước khi đụng filesystem/process', () {
    test(
      'tên app không hợp lệ -> throw ArgumentError, không gọi flutter create',
      () async {
        await expectLater(generate(name: 'Invalid Name'), throwsArgumentError);
      },
    );

    test('org không hợp lệ -> throw ArgumentError', () async {
      await expectLater(
        generate(name: 'ok_name', org: 'not-an-org'),
        throwsArgumentError,
      );
    });
  });
}
