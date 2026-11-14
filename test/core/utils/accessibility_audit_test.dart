import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/accessibility_audit.dart';

/// Isolates one rule so a fixture can assert a single violation even when
/// another rule (e.g. the per-site tap check) also fires on the same source.
List<AuditRule> _only(AuditRuleId id) =>
    defaultAuditRules.where((r) => r.id == id).toList();

void main() {
  group('scanAccessibility: reducedMotionCoverage', () {
    test(
      'fixture cố tình lỗi: AnimationController không có reducedMotion -> bị bắt',
      () {
        final violations = scanAccessibility(
          fileContents: {
            'bad.dart': '''
class Bad extends State<X> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(vsync: this);
}
''',
          },
        );

        expect(violations, hasLength(1));
        expect(violations.single.ruleId, AuditRuleId.reducedMotionCoverage);
        expect(violations.single.severity, AuditSeverity.error);
        expect(violations.single.file, 'bad.dart');
      },
    );

    test(
      'fixture hợp lệ: AnimationController có tham chiếu reducedMotion -> không false fail',
      () {
        final violations = scanAccessibility(
          fileContents: {
            'good.dart': '''
class Good extends State<X> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(vsync: this);
  void build() {
    if (NeonTheme.reducedMotion(context)) controller.value = 1;
  }
}
''',
          },
        );

        expect(violations, isEmpty);
      },
    );

    test(
      'file không có AnimationController -> rule không áp dụng, không báo gì',
      () {
        final violations = scanAccessibility(
          fileContents: {
            'plain.dart': 'class Plain extends StatelessWidget {}',
          },
        );
        expect(violations, isEmpty);
      },
    );
  });

  group('scanAccessibility: tapTargetSemantics', () {
    test(
      'fixture cố tình lỗi: GestureDetector không có Semantics -> bị bắt',
      () {
        final violations = scanAccessibility(
          rules: _only(AuditRuleId.tapTargetSemantics),
          fileContents: {
            'bad_tap.dart': '''
Widget build(BuildContext context) {
  return GestureDetector(onTap: () {}, child: Text('tap me'));
}
''',
          },
        );

        expect(violations, hasLength(1));
        expect(violations.single.ruleId, AuditRuleId.tapTargetSemantics);
        expect(violations.single.severity, AuditSeverity.warning);
      },
    );

    test(
      'fixture hợp lệ: GestureDetector có Semantics -> không false fail',
      () {
        final violations = scanAccessibility(
          rules: _only(AuditRuleId.tapTargetSemantics),
          fileContents: {
            'good_tap.dart': '''
Widget build(BuildContext context) {
  return Semantics(
    button: true,
    label: 'Tap me',
    child: GestureDetector(onTap: () {}, child: Text('tap me')),
  );
}
''',
          },
        );
        expect(violations, isEmpty);
      },
    );

    test(
      'fixture hợp lệ: dùng ExcludeSemantics (trang trí, có lý do rõ) -> không false fail',
      () {
        final violations = scanAccessibility(
          rules: _only(AuditRuleId.tapTargetSemantics),
          fileContents: {
            'decor_tap.dart': '''
Widget build(BuildContext context) {
  return ExcludeSemantics(
    child: InkWell(onTap: () {}, child: const Icon(Icons.star)),
  );
}
''',
          },
        );
        expect(violations, isEmpty);
      },
    );

    test('InkWell cũng bị áp dụng rule y hệt GestureDetector', () {
      final violations = scanAccessibility(
        rules: _only(AuditRuleId.tapTargetSemantics),
        fileContents: {
          'bad_ink.dart': "InkWell(onTap: () {}, child: Text('x'))",
        },
      );
      expect(violations, hasLength(1));
      expect(violations.single.ruleId, AuditRuleId.tapTargetSemantics);
    });
  });

  group('scanAccessibility: tapTargetSize (FEAT-202)', () {
    List<AuditViolation> scan(String src) => scanAccessibility(
      rules: _only(AuditRuleId.tapTargetSize),
      fileContents: {'w.dart': src},
    );

    test('warns on explicit width or height below 48 near a tap recognizer', () {
      for (final src in [
        'SizedBox(width: 32, child: GestureDetector(onTap: f))',
        'SizedBox(height: 47.5, child: InkWell(onTap: f))',
        'InkWell(onTap: f, child: SizedBox(width: 24))',
      ]) {
        final violations = scan(src);
        expect(violations, hasLength(1), reason: src);
        expect(violations.single.ruleId, AuditRuleId.tapTargetSize);
        expect(violations.single.severity, AuditSeverity.warning);
      }
    });

    test('ignores 48-or-larger and dynamic dimensions', () {
      for (final src in [
        'SizedBox(width: 48, child: GestureDetector(onTap: f))',
        'SizedBox(height: 56, child: InkWell(onTap: f))',
        'SizedBox(width: targetSize, child: GestureDetector(onTap: f))',
        'SizedBox(width: 48, child: GestureDetector(onTap: f)) // width: 24',
      ]) {
        expect(scan(src), isEmpty, reason: src);
      }
    });

    test('same-line a11y-ok suppression requires a reason', () {
      expect(
        scan('SizedBox(width: 32, // a11y-ok: decorative hit region\n'
            'child: GestureDetector(onTap: f))'),
        isEmpty,
      );
      expect(
        scan('SizedBox(width: 32, // a11y-ok:\n'
            'child: GestureDetector(onTap: f))'),
        hasLength(1),
      );
    });

    test('size heuristic remains independent from tap semantics rule', () {
      final src =
          'Semantics(button: true, child: SizedBox(width: 32, '
          'child: GestureDetector(onTap: f)))';
      expect(
        scanAccessibility(
          rules: _only(AuditRuleId.tapTargetSite),
          fileContents: {'w.dart': src},
        ),
        isEmpty,
      );
      expect(scan(src), hasLength(1));
    });
  });

  group('scanAccessibility: hardcodedString (FEAT-203)', () {
    List<AuditViolation> scan(String src) => scanAccessibility(
      rules: _only(AuditRuleId.hardcodedString),
      fileContents: {'w.dart': src},
    );

    test(
      'Text, label:, title:, message: với chuỗi tiếng Anh bị báo (info)',
      () {
        for (final src in [
          "Text('Claim reward')",
          "label: 'Retry now',",
          "title: 'Welcome back',",
          "message: 'No items yet',",
          "semanticLabel: 'Close dialog',",
        ]) {
          final v = scan(src);
          expect(v, hasLength(1), reason: src);
          expect(v.single.severity, AuditSeverity.info);
        }
      },
    );

    test('chuỗi nội suy, ký hiệu, token, .tr và comment không bị báo', () {
      for (final src in [
        r"Text('Level $level')",
        "Text('42')",
        "Text('x')",
        "Text('level_up_skip'.tr)",
        "// Text('Hidden comment text')",
        "child: Icon(Icons.close)",
      ]) {
        expect(scan(src), isEmpty, reason: src);
      }
    });
  });

  group('scanAccessibility: tapTargetSite (FEAT-202)', () {
    List<AuditViolation> scan(String src) => scanAccessibility(
      rules: _only(AuditRuleId.tapTargetSite),
      fileContents: {'w.dart': src},
    );

    test('bắt GestureDetector trần dù file có Semantics ở chỗ khác (rule theo '
        'file bỏ sót)', () {
      final src =
          '''
Widget a() => Semantics(label: 'a', child: Text('a'));
${List.filled(40, '// filler').join('\n')}
Widget b() => GestureDetector(onTap: () {}, child: Text('b'));
''';
      expect(scan(src).single.ruleId, AuditRuleId.tapTargetSite);
      expect(
        scanAccessibility(
          rules: _only(AuditRuleId.tapTargetSemantics),
          fileContents: {'w.dart': src},
        ),
        isEmpty,
        reason: 'rule theo file bị 1 Semantics( bất kỳ làm im lặng',
      );
    });

    test('không báo khi Semantics bọc ngay quanh hoặc nằm ngay sau', () {
      expect(
        scan("Semantics(button: true, child: GestureDetector(onTap: () {}))"),
        isEmpty,
      );
      expect(
        scan("GestureDetector(onTap: () {}, child: Semantics(label: 'x'))"),
        isEmpty,
      );
    });

    test('mỗi vị trí đếm riêng: 2 vị trí trần xa nhau vẫn chỉ ra 1 vi phạm '
        'cho file (mức file)', () {
      final gap = List.filled(50, 'Widget pad;').join('\n');
      expect(
        scan("GestureDetector(onTap: () {})\n$gap\nInkWell(onTap: () {})"),
        hasLength(1),
      );
    });
  });

  group('scanAccessibility: hardcodedColor (FEAT-201)', () {
    List<AuditViolation> scan(String src) =>
        scanAccessibility(fileContents: {'w.dart': src});

    test('Colors.orange và Color(0x..) bị bắt', () {
      expect(
        scan('color: Colors.orange,').single.ruleId,
        AuditRuleId.hardcodedColor,
      );
      expect(
        scan('color: const Color(0xFF123456),').single.ruleId,
        AuditRuleId.hardcodedColor,
      );
    });

    test('transparent/white/black (kể cả black54) không bị báo', () {
      expect(
        scan('color: Colors.transparent, a: Colors.white, b: Colors.black54,'),
        isEmpty,
      );
    });

    test('token NeonTheme và comment không bị báo', () {
      expect(scan('color: NeonTheme.ink, // Colors.red cũ'), isEmpty);
      expect(scan('color: myColors.red,'), isEmpty);
    });
  });

  group('scanAccessibility: rtlDirectionalSafety', () {
    test('fixture cố tình lỗi: EdgeInsets.only(left:) -> bị bắt', () {
      final violations = scanAccessibility(
        fileContents: {
          'bad_rtl.dart': 'padding: const EdgeInsets.only(left: 8),',
        },
      );
      expect(violations, hasLength(1));
      expect(violations.single.ruleId, AuditRuleId.rtlDirectionalSafety);
    });

    test('fixture cố tình lỗi: Positioned(right:) -> bị bắt', () {
      final violations = scanAccessibility(
        fileContents: {
          'bad_pos.dart': 'Positioned(right: 0, top: 0, child: X())',
        },
      );
      expect(violations, hasLength(1));
      expect(violations.single.ruleId, AuditRuleId.rtlDirectionalSafety);
    });

    test(
      'fixture hợp lệ: EdgeInsetsDirectional(start:) -> không false fail',
      () {
        final violations = scanAccessibility(
          fileContents: {
            'good_rtl.dart':
                'padding: const EdgeInsetsDirectional.only(start: 8),',
          },
        );
        expect(violations, isEmpty);
      },
    );

    test(
      'fixture hợp lệ: chỉ dùng top:/bottom: -> không false fail (không phải trục ngang)',
      () {
        final violations = scanAccessibility(
          fileContents: {
            'good_vertical.dart': 'EdgeInsets.only(top: 8, bottom: 4)',
          },
        );
        expect(violations, isEmpty);
      },
    );

    test(
      'PHÁT HIỆN THẬT: pattern trong doc comment (vd `/// ...(top: -2, right: -2)`) '
      'không bị tính là code thật — false positive tìm được khi chạy CLI thật trên repo',
      () {
        final violations = scanAccessibility(
          fileContents: {
            'doc_only.dart': '''
/// Usage: `Stack(children: [X(), Positioned(top: -2, right: -2, child: BadgeDot())])`.
class Real extends StatelessWidget {}
''',
          },
        );
        expect(violations, isEmpty);
      },
    );

    test(
      'code thật trên cùng dòng với // comment vẫn bị bắt (chỉ cắt phần sau //)',
      () {
        final violations = scanAccessibility(
          fileContents: {
            'mixed.dart':
                'padding: const EdgeInsets.only(left: 8), // TODO: fix RTL sau',
          },
        );
        expect(violations, hasLength(1));
      },
    );
  });

  group('AuditBaseline: suppress có lý do', () {
    test(
      'suppress đúng 1 (file, rule) cụ thể, không ảnh hưởng violation khác',
      () {
        final baseline = AuditBaseline.fromJson([
          {
            'file': 'legacy.dart',
            'rule': 'tapTargetSemantics',
            'reason': 'wrapper chung, caller tự quản semantics của content',
          },
        ]);

        final violations = scanAccessibility(
          rules: _only(AuditRuleId.tapTargetSemantics),
          fileContents: {
            'legacy.dart': "GestureDetector(onTap: () {}, child: Text('x'))",
            'other.dart': "InkWell(onTap: () {}, child: Text('y'))",
          },
          baseline: baseline,
        );

        expect(violations, hasLength(1));
        expect(violations.single.file, 'other.dart');
      },
    );

    test(
      'entry thiếu reason (rỗng) bị bỏ qua hoàn toàn -> vẫn báo violation bình thường',
      () {
        final baseline = AuditBaseline.fromJson([
          {'file': 'legacy.dart', 'rule': 'tapTargetSemantics', 'reason': ''},
        ]);

        final violations = scanAccessibility(
          rules: _only(AuditRuleId.tapTargetSemantics),
          fileContents: {
            'legacy.dart': "GestureDetector(onTap: () {}, child: Text('x'))",
          },
          baseline: baseline,
        );

        expect(
          violations,
          hasLength(1),
          reason: 'reason rỗng -> baseline entry vô hiệu, không suppress được',
        );
      },
    );

    test('entry rule id không tồn tại -> bị bỏ qua, không throw', () {
      expect(
        () => AuditBaseline.fromJson([
          {'file': 'x.dart', 'rule': 'khong_ton_tai', 'reason': 'a'},
        ]),
        returnsNormally,
      );
      final baseline = AuditBaseline.fromJson([
        {'file': 'x.dart', 'rule': 'khong_ton_tai', 'reason': 'a'},
      ]);
      expect(baseline.suppressions, isEmpty);
    });

    test(
      'map rác lẫn trong list JSON không làm hỏng các entry hợp lệ khác',
      () {
        final baseline = AuditBaseline.fromJson([
          {
            'file': 'ok.dart',
            'rule': 'rtlDirectionalSafety',
            'reason': 'debug-only overlay',
          },
          'garbage',
          42,
          null,
          {'file': 'bad_missing_field.dart', 'rule': 'rtlDirectionalSafety'},
        ]);
        expect(baseline.suppressions, hasLength(1));
        expect(baseline.suppressions.single.file, 'ok.dart');
      },
    );
  });

  group('scanAccessibility: nhiều rule/nhiều file cùng lúc', () {
    test('1 file vi phạm nhiều rule cùng lúc -> báo đủ, không chỉ 1', () {
      final violations = scanAccessibility(
        fileContents: {
          'multi.dart': '''
AnimationController(vsync: this);
GestureDetector(onTap: () {}, child: SizedBox(width: 32, child: Text('x')));
EdgeInsets.only(left: 4);
Colors.orange;
Text('Claim reward');
''',
        },
      );
      expect(violations, hasLength(AuditRuleId.values.length));
      expect(violations.map((v) => v.ruleId), containsAll(AuditRuleId.values));
    });

    test(
      'file sạch hoàn toàn -> không có trong kết quả (không báo "clean" thừa)',
      () {
        final violations = scanAccessibility(
          rules: _only(AuditRuleId.tapTargetSemantics),
          fileContents: {
            'clean.dart': "class Clean extends StatelessWidget {}",
            'dirty.dart': "GestureDetector(onTap: () {})",
          },
        );
        expect(violations, hasLength(1));
        expect(violations.every((v) => v.file != 'clean.dart'), isTrue);
      },
    );
  });
}
