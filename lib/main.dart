import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_dart/firebase_dart.dart';
import 'package:firebase_dart_flutter/firebase_dart_flutter.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_info2/system_info2.dart';
import 'package:win_toast/win_toast.dart';
import 'package:window_manager/window_manager.dart';
import 'package:wtnews/pages/loading.dart';
import 'package:wtnews/providers.dart';
import 'package:wtnews/services/dsn.dart';
import 'package:wtnews/services/firebase_data.dart';
import 'package:wtnews/widgets/top_widget.dart';

late final FirebaseApp app;
final String pathToVersion =
    '${p.dirname(Platform.resolvedExecutable)}\\data\\flutter_assets\\assets\\install\\version.txt';
final String pathToEcho =
    '${p.dirname(Platform.resolvedExecutable)}\\data\\flutter_assets\\assets\\manifest\\echo.bat';
final String pathToShortcut =
    '${p.dirname(Platform.resolvedExecutable)}\\data\\flutter_assets\\assets\\manifest\\WTNewsShortcut.bat';
final String newSound = p.joinAll([
  p.dirname(Platform.resolvedExecutable),
  'data\\flutter_assets\\assets\\sound\\new.wav'
]);
late final SharedPreferences prefs;
final provider = MyProvider();
final deviceInfo = DeviceInfoPlugin();
final Dio dio = Dio();
final winToast = WinToast.instance();
late final String appVersion;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await Window.initialize();
  prefs = await SharedPreferences.getInstance();
  provider.userNameProvider =
      StateProvider((ref) => prefs.getString('userName'));
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setResizable(true);
    await windowManager.setTitle('WTNews');
    await windowManager.setIcon('assets/app_icon.ico');
    await windowManager.setMinimumSize(const Size(628, 90));
    if (SysInfo.operatingSystemName.contains('Windows 11')) {
      await Window.setEffect(
          effect: WindowEffect.acrylic,
          color: const Color(0xCC222222),
          dark: true);
    } else {
      await Window.setEffect(
          effect: WindowEffect.aero,
          color: const Color(0xCC222222),
          dark: true);
    }

    await windowManager.show();
  });
  await winToast.initialize(
      appName: 'WTNews', productName: 'WTNews', companyName: 'Vonarian');
  await FirebaseDartFlutter.setup();
  app = await Firebase.initializeApp(
      options: FirebaseOptions.fromMap(firebaseConfig), name: 'wtnews-54364');
  runZonedGuarded(() async {
    Sentry.configureScope((scope) => scope.setUser(SentryUser(
        username: prefs.getString('userName'),
        ipAddress: scope.user?.ipAddress)));
    appVersion = await File(pathToVersion).readAsString();

    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.tracesSampleRate = 1.0;
        options.enableAutoSessionTracking = true;
        options.enableOutOfMemoryTracking = true;
        options.reportPackages = true;
        options.release = 'WTNews@$appVersion';
        options.tracesSampler = (samplingContext) {
          return 0.6;
        };
      },
    );
    if (prefs.getString('userName') != null &&
        prefs.getString('userName') != '' &&
        prefs.getBool('additionalNotif') != null &&
        prefs.getBool('additionalNotif')!) {
      winToast.showToast(
          type: ToastType.text04,
          subtitle: 'Welcome back ${prefs.getString('userName')} :)',
          title: 'Hi!');
    }
    runApp(ProviderScope(
      child: App(startup: args.contains('startup'), child: const Loading()),
    ));
  }, (exception, stackTrace) async {
    await Sentry.captureException(exception, stackTrace: stackTrace);
  });
}
