import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'core/neon_theme.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const NeonJewelsApp());
}

class NeonJewelsApp extends StatelessWidget {
  const NeonJewelsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Neon Jewels',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: NeonTheme.bgDark,
        colorScheme: const ColorScheme.dark(
          primary: NeonTheme.cyan,
          secondary: NeonTheme.magenta,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
