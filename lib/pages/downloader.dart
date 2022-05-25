import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:win_toast/win_toast.dart';
import 'package:window_manager/window_manager.dart';

import '../services/github.dart';
import '../widgets/custom_loading.dart';

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
    await WinToast.instance().showToast(
        type: ToastType.text04,
        title: 'Updating WTNews...',
        subtitle:
            'WTNews is downloading update, please do not close the application');
    await windowManager.setMinimumSize(const Size(230, 300));
    await windowManager.setMaximumSize(const Size(600, 600));
    await windowManager.setSize(const Size(230, 300));
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
      Dio dio = Dio();
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

        await WinToast.instance().showToast(
            type: ToastType.text04,
            title: 'Update process starting in a moment',
            subtitle:
                'Do not close the application until the update process is finished');
        text = 'Installing';
        setState(() {});

        await Future.delayed(const Duration(seconds: 1));
        await Process.start('powershell.exe', [
          'Add-AppPackage',
          '-Path',
          "'${tempWtnews.path}\\out\\WTNews.msix'"
        ]);
        await Future.delayed(const Duration(seconds: 2));
        await Process.run(installer, [], runInShell: true);

        // await Process.run(installer, []);
      }).timeout(const Duration(minutes: 8));
    } catch (e, st) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 10),
          content: Text(e.toString()),
          action: SnackBarAction(
            onPressed: () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => const Downloader()));
            },
            label: 'Retry',
          ),
        ));
      await windowManager.setSize(const Size(600, 600));
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
      child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
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
                          Center(
                            child: CustomLoadingAnimationWidget.inkDrop(
                                color: Color.lerp(
                                        Colors.red, Colors.amber, 0.77) ??
                                    Colors.red,
                                size: 150,
                                strokeWidth: 10,
                                colors: [
                                  Colors.red,
                                  Colors.blue,
                                  Colors.green,
                                  Colors.amber,
                                  Colors.pink
                                ]),
                          ),
                          Center(
                            child: Text(
                              text,
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.white),
                            ),
                          ),
                          Center(
                            child: Text(
                              '${progress.toStringAsFixed(1)} %',
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          )),
    );
  }

  final bool _showWindowBelowTrayIcon = false;
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
    if (_showWindowBelowTrayIcon) {
      Size windowSize = await windowManager.getSize();
      Rect trayIconBounds = await tray.TrayManager.instance.getBounds();
      Size trayIconSize = trayIconBounds.size;
      Offset trayIconNewPosition = trayIconBounds.topLeft;

      Offset newPosition = Offset(
        trayIconNewPosition.dx - ((windowSize.width - trayIconSize.width) / 2),
        trayIconNewPosition.dy,
      );

      windowManager.setPosition(newPosition);
      await Future.delayed(const Duration(milliseconds: 100));
    }
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
