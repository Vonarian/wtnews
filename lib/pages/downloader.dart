import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show SnackBarAction;
import 'package:local_notifier/local_notifier.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';
import 'package:wtnews/von_assistant/von_assistant.dart';

import '../main.dart';
import '../services/data/github.dart';

class Downloader extends StatefulWidget {
  const Downloader({Key? key}) : super(key: key);

  @override
  DownloaderState createState() => DownloaderState();
}

class DownloaderState extends State<Downloader>
    with WindowListener, tray.TrayListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    tray.trayManager.addListener(this);
    downloadUpdate();
  }

  @override
  void dispose() {
    super.dispose();
    windowManager.removeListener(this);
    tray.trayManager.removeListener(this);
  }

  Future<void> downloadUpdate() async {
    LocalNotification(
            title: 'Updating WTNews...',
            body:
                'WTNews is downloading update, please do not close the application')
        .show();
    await windowManager.setMinimumSize(const Size(230, 300));
    await windowManager.setMaximumSize(const Size(600, 600));
    await windowManager.setSize(const Size(230, 300));
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.center();
    try {
      GHData data = await GHData.getData();
      Directory tempDir = await getTemporaryDirectory();
      String tempPath = tempDir.path;
      Directory tempWtnews =
          await Directory('$tempPath\\WTNews').create(recursive: true);
      final deleteFolder = Directory(p.joinAll([tempWtnews.path, 'out']));
      if (await deleteFolder.exists()) {
        await deleteFolder.delete(recursive: true);
      }

      await dio.download(
          data.assets.last.browserDownloadUrl, '${tempWtnews.path}\\update.zip',
          onReceiveProgress: (downloaded, full) async {
        progress = downloaded / full * 100;
        setState(() {});
      }, deleteOnError: true).whenComplete(() async {
        final File filePath = File('${tempWtnews.path}\\update.zip');
        final Uint8List bytes =
            await File('${tempWtnews.path}\\update.zip').readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final file in archive) {
          final filename = file.name;
          if (file.isFile) {
            final data = file.content as List<int>;
            File('${p.dirname(filePath.path)}\\out\\$filename')
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          } else {
            Directory('${p.dirname(filePath.path)}\\out\\$filename')
                .create(recursive: true);
          }
        }
        final path = '${tempWtnews.path}\\out';
        text = 'Installing';
        setState(() {});
        final von = await VonAssistant.initialize(appDocPath);
        await von.installAppUpdate(path);
      }).timeout(const Duration(minutes: 8));
    } catch (e, st) {
      if (!mounted) return;

      showSnackbar(
          context,
          Snackbar(
            content: Text(
              e.toString(),
              style: TextStyle(color: Colors.red),
            ),
            action: SnackBarAction(
              onPressed: () {
                Navigator.pushReplacement(context,
                    FluentPageRoute(builder: (context) => const Downloader()));
              },
              label: 'Retry',
            ),
            extended: true,
          ),
          duration: const Duration(seconds: 10));
      windowManager.setSize(const Size(600, 600));
      await Sentry.captureException(e, stackTrace: st);
      error = true;
      text = 'ERROR!';
      setState(() {});
    }
  }

  String text = 'Downloading';
  bool error = false;
  double progress = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: ScaffoldPage(
          content: Center(
        child: SizedBox(
          height: 200,
          width: 200,
          child: Stack(
            children: [
              SizedBox(
                  height: 200,
                  width: 200,
                  child: ProgressRing(
                    value: progress,
                  )),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      text,
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                    ),
                    Text(
                      '${progress.toStringAsFixed(1)} %',
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }

  Future<void> _handleClickRestore() async {
    await windowManager.setIcon('assets/app_icon.ico');
    windowManager.restore();
    windowManager.show();
  }

  Future<void> _trayInit() async {
    await tray.trayManager.setIcon(
      'assets/app_icon.ico',
    );
    tray.Menu menu = tray.Menu(items: [
      tray.MenuItem(key: 'show-app', label: 'Show'),
      tray.MenuItem.separator(),
      tray.MenuItem(key: 'close-app', label: 'Exit'),
    ]);
    await tray.trayManager.setContextMenu(menu);
  }

  @override
  void onWindowMinimize() {
    windowManager.hide();
    _trayInit();
  }

  void _trayUnInit() async {
    await tray.trayManager.destroy();
  }

  @override
  void onTrayIconMouseDown() async {
    _handleClickRestore();
    _trayUnInit();
  }

  @override
  void onTrayIconRightMouseDown() {
    tray.trayManager.popUpContextMenu();
  }

  @override
  void onWindowRestore() {
    setState(() {});
  }

  @override
  void onTrayMenuItemClick(tray.MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show-app':
        windowManager.show();
        break;
      case 'close-app':
        windowManager.close();
        break;
    }
  }
}
