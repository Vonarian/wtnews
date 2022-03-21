import 'dart:async';
import 'dart:io';

import 'package:firebase_dart/firebase_dart.dart';
import 'package:firebase_dart_flutter/firebase_dart_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win32/win32.dart';
import 'package:win_toast/win_toast.dart';
import 'package:window_manager/window_manager.dart';
import 'package:wtnews/pages/loading.dart';
import 'package:wtnews/services/dsn.dart';
import 'package:wtnews/services/firebase_data.dart';

final StateProvider<bool> isStartupEnabled = StateProvider((ref) => false);
final StateProvider<bool> playSound = StateProvider((ref) => true);
final StateProvider<String?> customFeed = StateProvider((ref) => null);
late FirebaseApp app;

String pathToUpdateShortcut =
    '${p.dirname(Platform.resolvedExecutable)}/data/flutter_assets/assets/manifest/updateShortcut.bat';
late SharedPreferences prefs;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  bool isStartupEnabled = prefs.getBool('startup') ?? false;
  if (isStartupEnabled && !kDebugMode) {
    Process.runSync(pathToUpdateShortcut, []);
  }
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setTitleBarStyle('hidden');
    await windowManager.setResizable(true);
    await windowManager.setTitle('WTNews');
    await windowManager.show();
  });
  await WinToast.instance().initialize(
      appName: 'WTNews', productName: 'WTNews', companyName: 'Vonarian');
  await FirebaseDartFlutter.setup();
  app = await Firebase.initializeApp(
      options: FirebaseOptions.fromMap(firebaseConfig), name: 'wtnews-54364');
  runZonedGuarded(() async {
    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.tracesSampleRate = 1.0;
        options.enableAutoSessionTracking = true;
        options.enableOutOfMemoryTracking = true;
        options.reportPackages = false;
        // OR if you prefer, determine traces sample rate based on the sampling context
        options.tracesSampler = (samplingContext) {
          return 1.0;
        };
      },
    );

    runApp(ProviderScope(
      child: MaterialApp(
        title: 'WTNews',
        themeMode: ThemeMode.dark,
        debugShowCheckedModeBanner: false,
        home: const Loading(),
        navigatorObservers: [SentryNavigatorObserver()],
      ),
    ));
  }, (exception, stackTrace) async {
    await Sentry.captureException(exception, stackTrace: stackTrace);
  });
}

void soundPlayer(String path) {
  final file = File(path).existsSync();

  if (!file) {
    if (kDebugMode) {
      print('WAV file missing.');
    }
  } else {
    final soundFile = TEXT(path);
    final result = PlaySound(soundFile, NULL, SND_FILENAME | SND_SYNC);

    if (result != TRUE) {
      if (kDebugMode) {
        print('Sound playback failed.');
      }
    }
    free(soundFile);
  }
}
