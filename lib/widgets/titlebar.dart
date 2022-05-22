import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:url_launcher/url_launcher.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:webfeed/domain/rss_item.dart';
import 'package:win_toast/win_toast.dart';
import 'package:window_manager/window_manager.dart';
import 'package:wtnews/providers.dart';
import 'package:wtnews/services/utility.dart';

import '../main.dart';
import '../pages/settings.dart';

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
  _WindowTitleBarState createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends ConsumerState<WindowTitleBar>
    with tray.TrayListener, WindowListener, ProtocolListener {
  @override
  void initState() {
    super.initState();
    tray.trayManager.addListener(this);
    windowManager.addListener(this);
    protocolHandler.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(checkDataMine.notifier).state =
          prefs.getBool('checkDataMine') ?? false;
    });
    lastPubDate.addListener(() async {
      await notify(lastPubDate.value!, lastItemLink!);
      await prefs.setString('previous', lastPubDate.value!);
    });
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (ref.watch(checkDataMine)) {
        rssFeed = await getDataMine()
            .timeout(const Duration(seconds: 10))
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
  String? lastItemLink;
  RssFeed? rssFeed;
  @override
  Widget build(BuildContext context) {
    return _MoveWindow(
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: 40,
        child: Flex(
          direction: Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            !widget.isCustom
                ? Expanded(
                    child: Image.asset(
                    'assets/app_icon.ico',
                    alignment: Alignment.centerLeft,
                  ))
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
    WinToast.instance().showToast(
        type: ToastType.text04,
        title: 'WTNews is minimized to tray',
        subtitle: 'Check tray to open app again');
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
