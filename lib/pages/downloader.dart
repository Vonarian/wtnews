import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:blinking_text/blinking_text.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show SnackBarAction;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:win_toast/win_toast.dart';
import 'package:window_manager/window_manager.dart';

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
    await winToast.showToast(
        type: ToastType.text04,
        title: 'Updating WTNews...',
        subtitle:
            'WTNews is downloading update, please do not close the application');
    await windowManager.setMinimumSize(const Size(230, 300));
    await windowManager.setMaximumSize(const Size(600, 600));
    await windowManager.setSize(const Size(230, 300));
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.center();
    try {
      Data data = await Data.getData();
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

        String installer = (p.joinAll([
          ...p.split(p.dirname(Platform.resolvedExecutable)),
          'data',
          'flutter_assets',
          'assets',
          'install',
          'installer.bat'
        ]));

        await winToast.showToast(
            type: ToastType.text04,
            title: 'Update process starting in a moment',
            subtitle:
                'Do not close the application until the update process is finished');
        text = 'Installing';
        setState(() {});
        await Process.run(installer, [tempWtnews.path],
            runInShell: true, workingDirectory: p.dirname(installer));
      }).timeout(const Duration(minutes: 8));
    } catch (e, st) {
      if (!mounted) return;

      showSnackbar(
          context,
          Snackbar(
            content: BlinkText(
              e.toString(),
              endColor: Colors.red,
              duration: const Duration(milliseconds: 300),
            ),
            action: SnackBarAction(
              onPressed: () {
                Navigator.pushReplacement(context,
                    FluentPageRoute(builder: (context) => const Downloader()));
              },
              label: 'Retry',
            ),
            extended: true,
          ));
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
          child: text == 'Downloading'
              ? CircularPercentIndicator(
                  center: !error
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              text,
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.white),
                            ),
                            Text(
                              '${progress.toStringAsFixed(1)} %',
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.white),
                            ),
                          ],
                        )
                      : const Center(
                          child: Text(
                            'ERROR',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                  backgroundColor: Colors.blue,
                  percent: double.parse(progress.toStringAsFixed(0)) / 100,
                  radius: 100,
                )
              : Center(
                  child: Stack(
                    children: [
                      const Center(
                          child: ProgressRing(
                        strokeWidth: 10,
                      )),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              text,
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.white),
                            ),
                            Text(
                              '${progress.toStringAsFixed(1)} %',
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
