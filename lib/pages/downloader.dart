import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:win_toast/win_toast.dart';
import 'package:window_manager/window_manager.dart';

import '../services/github.dart';

class Downloader extends StatefulWidget {
  const Downloader({Key? key}) : super(key: key);

  @override
  _DownloaderState createState() => _DownloaderState();
}

class _DownloaderState extends State<Downloader>
    with WindowListener, TrayListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    downloadUpdate();
  }

  @override
  void dispose() {
    super.dispose();
    windowManager.removeListener(this);
    trayManager.removeListener(this);
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
      final deleteFile = File(p.joinAll([tempWtnews.path, 'update.zip']));
      final deleteFolder = Directory(p.joinAll([tempWtnews.path, 'out']));
      if (await deleteFile.exists() || await deleteFolder.exists()) {
        await deleteFile.delete(recursive: true);
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
        await Future.delayed(const Duration(seconds: 1));
        await Process.run(installer, []);
      }).timeout(const Duration(minutes: 8));
    } catch (e, st) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
            duration: const Duration(seconds: 10),
            content: Text(e.toString())));
      await Sentry.captureException(e, stackTrace: st);
      error = true;
      await windowManager.setSize(const Size(600, 600));
      setState(() {});
    }
  }

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
                child: CircularPercentIndicator(
                  center: !error
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Downloading',
                              style:
                                  TextStyle(fontSize: 15, color: Colors.white),
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
                )),
          )),
    );
  }

  final bool _showWindowBelowTrayIcon = false;
  Future<void> _handleClickRestore() async {
    windowManager.restore();
    windowManager.show();
  }

  @override
  void onTrayIconMouseDown() async {
    if (_showWindowBelowTrayIcon) {
      Size windowSize = await windowManager.getSize();
      Rect trayIconBounds = await TrayManager.instance.getBounds();
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
  }
}
