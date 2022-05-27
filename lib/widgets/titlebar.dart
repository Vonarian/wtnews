import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:protocol_handler/protocol_handler.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:url_launcher/url_launcher.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:webfeed/domain/rss_item.dart';
import 'package:win_toast/win_toast.dart';
import 'package:window_manager/window_manager.dart';
import 'package:wtnews/pages/downloader.dart';
import 'package:wtnews/providers.dart';
import 'package:wtnews/services/utility.dart';

import '../main.dart';
import '../pages/settings.dart';
import '../services/presence.dart';

class _MoveWindow extends StatelessWidget {
  const _MoveWindow({Key? key, required this.child}) : super(key: key);
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (details) {
          windowManager.startDragging();
        },
        onDoubleTap: () async {
          if (!await windowManager.isMaximized()) {
            await windowManager.maximize();
          } else {
            await windowManager.unmaximize();
          }
        },
        child: child);
  }
}

class WindowTitleBar extends ConsumerStatefulWidget {
  final bool isCustom;
  const WindowTitleBar({Key? key, required this.isCustom}) : super(key: key);

  @override
  WindowTitleBarState createState() => WindowTitleBarState();
}

class WindowTitleBarState extends ConsumerState<WindowTitleBar>
    with tray.TrayListener, WindowListener, ProtocolListener {
  @override
  void initState() {
    super.initState();
    tray.trayManager.addListener(this);
    windowManager.addListener(this);
    protocolHandler.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      future = autoUpdateCheck(context);
      ref.read(checkDataMine.notifier).state =
          prefs.getBool('checkDataMine') ?? false;
    });
    lastPubDate.addListener(() async {
      await notify(lastPubDate.value!, lastItemLink!);
      await prefs.setString('previous', lastPubDate.value!);
    });

    Timer.periodic(const Duration(seconds: 35), (timer) async {
      future = autoUpdateCheck(context);
      setState(() {});
    });

    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (ref.watch(checkDataMine)) {
        rssFeed = await getDataMine()
            .timeout(const Duration(seconds: 25))
            .whenComplete(() async {
          if (rssFeed != null && rssFeed?.items != null) {
            RssItem item = rssFeed!.items!.first;
            if (item.description != null) {
              String itemDescription = item.description!;
              bool? isDataMine = (itemDescription.contains('Raw changes:') &&
                      itemDescription.contains('→') &&
                      itemDescription.contains('Current dev version')) ||
                  itemDescription.contains('	');
              if (isDataMine) {
                if (lastPubDate.value != item.pubDate.toString()) {
                  lastPubDate.value = item.pubDate.toString();
                  lastItemLink = item.link;
                }
              }
            }
          }
        });
      }
    });
  }

  Future<bool?> autoUpdateCheck(BuildContext ctx) async {
    final File file = File(
        '${p.dirname(Platform.resolvedExecutable)}/data/flutter_assets/assets/install/version.txt');
    final int currentVersion =
        int.parse((await file.readAsString()).replaceAll('.', ''));
    final String? version = (await PresenceService().getVersion());
    if (version != null) {
      if (version != ref.read(versionProvider.notifier).state) {
        ref.read(versionProvider.notifier).state = version;
      }
      final int serverVersion = int.parse(version.replaceAll('.', ''));
      if (serverVersion > currentVersion) {
        return true;
      }
    }
    return null;
  }

  Future<RssFeed> getDataMine() async {
    Dio dio = Dio();
    Response response = await dio
        .get('https://forum.warthunder.com/index.php?/discover/704.xml');
    RssFeed rssFeed = RssFeed.parse(response.data);
    return rssFeed;
  }

  Future<void> notify(String pubDate, String url) async {
    if (prefs.getString('previous') != null) {
      if (prefs.getString('previous') != pubDate) {
        String? previous = prefs.getString('previous');
        if (kDebugMode) {
          print('isNew');
          print(previous);
          print(pubDate);
        }

        AppUtil().playSound(newSound);
        final toast = await WinToast.instance().showToast(
          title: 'New Data Mine',
          type: ToastType.text04,
          subtitle: 'Click to launch in browser',
        );
        toast?.eventStream.listen((event) {
          if (event is ActivatedEvent) {
            launchUrl(Uri.parse(url));
          }
        });
      }
    } else {
      if (kDebugMode) {
        print('Null');
      }
      AppUtil().playSound(newSound);
      final toast = await WinToast.instance().showToast(
          title: 'New Data Mine',
          type: ToastType.text04,
          subtitle: 'New Data Mine from gszabi');
      toast?.eventStream.listen((event) {
        if (event is ActivatedEvent) {
          launchUrl(Uri.parse(url));
        }
      });
    }
  }

  @override
  void dispose() {
    tray.trayManager.removeListener(this);
    windowManager.removeListener(this);
    protocolHandler.removeListener(this);
    lastPubDate.removeListener(() {});
    super.dispose();
  }

  ValueNotifier<String?> lastPubDate = ValueNotifier(null);
  Future<bool?>? future;
  String? lastItemLink;
  RssFeed? rssFeed;
  @override
  Widget build(BuildContext context) {
    ref.listen<StateController<String?>>(versionProvider.state,
        (previous, next) async {
      if ((await autoUpdateCheck(context) ?? false) &&
          previous != null &&
          previous != next) {
        var toast = await WinToast.instance().showToast(
            type: ToastType.text04,
            title: 'Update Available',
            subtitle: 'Click here to update');
        toast?.eventStream.listen((event) {
          if (event is ActivatedEvent) {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => const Downloader()));
          }
        });
      }
    });
    return _MoveWindow(
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: Flex(
          direction: Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            !widget.isCustom
                ? Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 27.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          child: Image.asset(
                            'assets/app_icon.ico',
                          ),
                          onTap: () {
                            launchUrl(Uri.parse(
                                'https://forum.warthunder.com/index.php?/topic/549057-wtnews-get-notified-of-forum-news/'));
                          },
                        ),
                      ),
                    ),
                  )
                : const SizedBox(),
            !widget.isCustom
                ? InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (c, a1, a2) => const Settings(),
                          transitionsBuilder: (c, anim, a2, child) =>
                              FadeTransition(opacity: anim, child: child),
                          transitionDuration: const Duration(milliseconds: 220),
                        ),
                      );
                    },
                    hoverColor: Colors.green.withOpacity(0.1),
                    child: Container(
                      alignment: Alignment.center,
                      width: 15,
                      height: 15,
                      margin: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                      child: const Icon(Icons.settings, color: Colors.green),
                    ),
                  )
                : const SizedBox(),
            FutureBuilder<bool?>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    if (snapshot.data as bool) {
                      return Center(
                        child: InkWell(
                          onTap: () {
                            Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const Downloader()));
                          },
                          hoverColor: Colors.blue.withOpacity(0.1),
                          child: Container(
                            width: 15,
                            height: 15,
                            margin: const EdgeInsets.fromLTRB(12, 8, 10, 25.5),
                            child:
                                const Icon(Icons.update, color: Colors.amber),
                          ),
                        ),
                      );
                    } else {
                      return const SizedBox();
                    }
                  } else {
                    return const SizedBox();
                  }
                }),
            InkWell(
              onTap: () {
                windowManager.minimize();
              },
              hoverColor: Colors.blue.withOpacity(0.1),
              child: Container(
                width: 15,
                height: 15,
                margin: const EdgeInsets.fromLTRB(12, 0, 10, 25.5),
                child: const Icon(Icons.minimize_outlined, color: Colors.blue),
              ),
            ),
            InkWell(
                onTap: () {
                  windowManager.close();
                  exit(0);
                },
                hoverColor: Colors.red.withOpacity(0.1),
                child: Container(
                  alignment: Alignment.center,
                  width: 15,
                  height: 15,
                  margin: const EdgeInsets.fromLTRB(12, 0, 18, 12),
                  child: const Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 25,
                  ),
                )),
          ],
        ),
      ),
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

  @override
  void onWindowMinimize() {
    windowManager.hide();
    _trayInit();
    if (prefs.getBool('additionalNotif') != null &&
        prefs.getBool('additionalNotif')!) {
      WinToast.instance().showToast(
          type: ToastType.text04,
          title: 'WTNews is minimized to tray',
          subtitle: 'Check tray to open app again');
    }
  }

  @override
  void onProtocolUrlReceived(String url) {
    if (url.contains('xml') && url.isNotEmpty) {
      ref.read(customFeed.notifier).state = url.replaceAll('wtnews:', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'New custom feed url: ${ref.read(customFeed.notifier).state}')));
      prefs.setString('customFeed', ref.read(customFeed.notifier).state!);
    }
  }
}
