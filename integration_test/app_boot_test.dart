import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roy_base_game/main.dart' as app;
import 'package:roy_base_game/presentation/screens/home_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots to HomeScreen', (tester) async {
    await app.app(withAudio: false);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
