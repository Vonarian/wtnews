import 'dart:async';
import 'dart:io';

import 'package:firebase_dart/firebase_dart.dart';
import 'package:firebase_dart_flutter/firebase_dart_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:protocol_handler/protocol_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win_toast/win_toast.dart';
import 'package:window_manager/window_manager.dart';
import 'package:wtnews/pages/loading.dart';
import 'package:wtnews/providers.dart';
import 'package:wtnews/services/dsn.dart';
import 'package:wtnews/services/firebase_data.dart';

late FirebaseApp app;
String pathToUpdateShortcut =
    '${p.dirname(Platform.resolvedExecutable)}\\data\\flutter_assets\\assets\\manifest\\updateShortcut.bat';
String pathToVersion =
    '${p.dirname(Platform.resolvedExecutable)}\\data\\flutter_assets\\assets\\install\\version.txt';
String pathAhkExe =
    '${p.dirname(Platform.resolvedExecutable)}\\data\\flutter_assets\\assets\\AHK\\AutoHotkeyU64.exe';
String pathAhkScript =
    '${p.dirname(Platform.resolvedExecutable)}\\data\\flutter_assets\\assets\\AHK\\AutoHotkeyU64.ahk';
String newSound = p.joinAll([
  p.dirname(Platform.resolvedExecutable),
  'data\\flutter_assets\\assets\\sound\\new.wav'
]);
late SharedPreferences prefs;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await Window.initialize();
  prefs = await SharedPreferences.getInstance();

  userNameProvider = StateProvider((ref) => prefs.getString('userName'));
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setResizable(true);
    await windowManager.setTitle('WTNews');
    await windowManager.setIcon('assets/app_icon.ico');
    await Window.hideWindowControls();
    await Window.setEffect(
      effect: WindowEffect.aero,
      color: Colors.black.withOpacity(0.55),
    );
    await windowManager.show();
  });
  await protocolHandler.register('wtnews');

  await WinToast.instance().initialize(
      appName: 'WTNews', productName: 'WTNews', companyName: 'Vonarian');
  await FirebaseDartFlutter.setup();
  app = await Firebase.initializeApp(
      options: FirebaseOptions.fromMap(firebaseConfig), name: 'wtnews-54364');
  runZonedGuarded(() async {
    Sentry.configureScope(
      (scope) => scope.user = SentryUser(
          username: prefs.getString('userName'),
          ipAddress: scope.user?.ipAddress),
    );
    final file = File(pathToVersion);

    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.tracesSampleRate = 1.0;
        options.enableAutoSessionTracking = true;
        options.enableOutOfMemoryTracking = true;
        options.reportPackages = true;
        options.release = 'WTNews@${file.readAsStringSync()}';
        options.tracesSampler = (samplingContext) {
          return 1.0;
        };
      },
    );
    if (prefs.getString('userName') != null &&
        prefs.getString('userName') != '' &&
        prefs.getBool('additionalNotif') != null &&
        prefs.getBool('additionalNotif')!) {
      WinToast.instance().showToast(
          type: ToastType.text04,
          subtitle: 'Welcome back ${prefs.getString('userName')} :)',
          title: 'Hi!');
    }
    runApp(Phoenix(
      child: const ProviderScope(
        child: MaterialApp(
          title: 'WTNews',
          themeMode: ThemeMode.dark,
          debugShowCheckedModeBanner: false,
          home: Loading(),
        ),
      ),
    ));
  }, (exception, stackTrace) async {
    await Sentry.captureException(exception, stackTrace: stackTrace);
  });
}
