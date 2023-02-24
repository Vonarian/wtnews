import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_dart/firebase_dart.dart';
import 'package:firebase_dart_flutter/firebase_dart_flutter.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_info2/system_info2.dart';
import 'package:window_manager/window_manager.dart';
import 'package:wtnews/pages/loading.dart';
import 'package:wtnews/services/data/dsn.dart';
import 'package:wtnews/services/data/firebase_data.dart';
import 'package:wtnews/widgets/top_widget.dart';

late final FirebaseApp app;
final String pathToVersion =
    '${p.dirname(Platform.resolvedExecutable)}\\data\\flutter_assets\\assets\\install\\version.txt';
final String newSound = p.joinAll([
  p.dirname(Platform.resolvedExecutable),
  'data\\flutter_assets\\assets\\sound\\new.wav'
]);
final deviceInfo = DeviceInfoPlugin();
final Dio dio = Dio();
late final String appVersion;
late final String uid;
late String appDocPath;
late final SharedPreferences prefs;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await Window.initialize();
  prefs = await SharedPreferences.getInstance();
  appDocPath = (await getApplicationDocumentsDirectory()).path;
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setResizable(true);
    await windowManager.setTitle('WTNews');
    await windowManager.setIcon('assets/app_icon.ico');
    await windowManager.setMinimumSize(const Size(628, 90));
    if (SysInfo.operatingSystemName.contains('Windows 11')) {
      await Window.setEffect(effect: WindowEffect.acrylic);
    } else {
      await Window.setEffect(
        effect: WindowEffect.aero,
        color: const Color(0xCC222222),
      );
    }

    await windowManager.show();
  });
  await localNotifier.setup(
      appName: 'WTNews', shortcutPolicy: ShortcutPolicy.ignore);
  uid = (await deviceInfo.windowsInfo).computerName;
  await FirebaseDartFlutter.setup(isolated: true);
  app = await Firebase.initializeApp(
      options: FirebaseOptions.fromMap(firebaseConfig), name: 'wtnews-54364');
  runZonedGuarded(() async {
    Sentry.configureScope((scope) =>
        scope.setUser(SentryUser(username: prefs.getString('userName'))));
    appVersion = await File(pathToVersion).readAsString();
    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.logger = (level, message, {exception, logger, stackTrace}) => {
              log('Level: $level'),
              log('Message: $message'),
              if (exception != null)
                log('Exception: $exception', stackTrace: stackTrace),
            };
        options.release = 'WTNews@$appVersion';
        options.tracesSampler = (samplingContext) {
          return 0.6;
        };
      },
    );
    runApp(ProviderScope(
      child: App(startup: args.isNotEmpty, child: Loading(prefs)),
    ));
  }, (exception, stackTrace) async {
    await Sentry.captureException(exception, stackTrace: stackTrace);
  });
}
