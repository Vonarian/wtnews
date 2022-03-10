import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:wtnews/pages/loading.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setTitleBarStyle('hidden');
    await windowManager.setResizable(true);
    await windowManager.setAspectRatio(1.777);
    await windowManager.show();
  });
  runApp(const MaterialApp(
    themeMode: ThemeMode.dark,
    debugShowCheckedModeBanner: false,
    home: Loading(),
  ));
}
