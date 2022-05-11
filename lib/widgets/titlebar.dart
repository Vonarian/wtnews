import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:win_toast/win_toast.dart';
import 'package:window_manager/window_manager.dart';
import 'package:wtnews/mainces/utility.dart';

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
    with TrayListener, WindowListener, ProtocolListener {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    protocolHandler.addListener(this);
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    protocolHandler.removeListener(this);
    super.dispose();
  }

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
                          transitionDuration: const Duration(milliseconds: 500),
                        ),
                      );
                    },
                    child: Container(
                      alignment: Alignment.center,
                      width: 15,
                      height: 15,
                      margin: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                      child: const Icon(Icons.settings, color: Colors.green),
                    ),
                    hoverColor: Colors.green,
                  )
                : const SizedBox(),
            InkWell(
              onTap: () {
                windowManager.minimize();
              },
              child: Container(
                width: 15,
                height: 15,
                margin: const EdgeInsets.fromLTRB(12, 0, 10, 25.5),
                child: const Icon(Icons.minimize_outlined, color: Colors.blue),
              ),
              hoverColor: Colors.blue,
            ),
            InkWell(
                onTap: () {
                  windowManager.close();
                  exit(0);
                },
                child: Container(
                  alignment: Alignment.center,
                  width: 15,
                  height: 15,
                  margin: const EdgeInsets.fromLTRB(12, 0, 14, 12),
                  child: const Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 25,
                  ),
                ),
                hoverColor: Colors.red),
          ],
        ),
      ),
    );
  }

  final bool _showWindowBelowTrayIcon = false;
  Future<void> _handleClickRestore() async {
    windowManager.restore();
    await windowManager.setIcon('assets/app_icon.ico');
    windowManager.show();
  }

  Future<void> _trayInit() async {
    await trayManager.setIcon(
      'assets/app_icon.ico',
    );
    Menu menu = Menu(items: [
      MenuItem(key: 'show-app', label: 'Show'),
      MenuItem.separator(),
      MenuItem(key: 'close-app', label: 'Exit'),
    ]);
    await trayManager.setContextMenu(menu);
  }

  void _trayUnInit() async {
    await trayManager.destroy();
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
    _trayUnInit();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('New custom feed url: $url')));
      prefs.setString('customFeed', url);
    }
  }
}
