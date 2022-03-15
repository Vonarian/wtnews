import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:win32/win32.dart';
import 'package:window_manager/window_manager.dart';
import 'package:wtnews/pages/loading.dart';

final StateProvider<bool> isStartupEnabled = StateProvider((ref) => false);
final StateProvider<bool> playSound = StateProvider((ref) => true);

final localNotifier = LocalNotifier.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setTitleBarStyle('hidden');
    await windowManager.setResizable(true);
    await windowManager.setAspectRatio(1.777);
    await windowManager.show();
  });
  runApp(const ProviderScope(
    child: MaterialApp(
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: Loading(),
    ),
  ));
}

void soundPlayer(String path) {
  final file = File(path).existsSync();

  if (!file) {
    print('WAV file missing.');
  } else {
    final pszLogonSound = TEXT(path);
    final result = PlaySound(pszLogonSound, NULL, SND_FILENAME | SND_SYNC);

    if (result != TRUE) {
      print('Sound playback failed.');
    }
    free(pszLogonSound);
  }
}
