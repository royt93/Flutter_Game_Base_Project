import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/debug_log.dart';

void main() {
  test('IDEA-71: dlog() luôn prefix "roy93~ " trong debug build, không đụng '
      'platform channel nào', () {
    final messages = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = original);

    dlog('hello world');

    expect(messages, contains('roy93~ hello world'));
  });
}
