import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roy_casual_kit_example/main.dart' as app;
import 'package:roy_casual_kit_example/screens/home_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots to HomeScreen', (tester) async {
    // withAudio mặc định `!isE2eTest` (lib/core/runtime_flags.dart) — chạy
    // với `--dart-define=E2E_TEST=true` để tắt audio init, tránh audioplayers
    // đăng ký frame callback còn sống sau tearDown.
    await app.app();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
